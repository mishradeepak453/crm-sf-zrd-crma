/**
 * SF-911 Account-Sync mittels Grace-Aufruf
 * The Service communicate with GRACE-API maps the response objects and upserts the fetched records.
 *
 * @group GRSY - Grace Sync Account
 * @date 08.04.2022
 * @author daniel.gette@zepplin.com
 * 
 * @version 2023-04-01  miriam.ida.tyroller@accenture.com adjusted fields and error handling 
 */
public without sharing class GRSYAccService {
    private final static Set<String> ACC_BOOLEAN_ZERO_ONE_FIELDS = new Set<String>{};

    private final static Set<String> ACC_DATETIME_FIELDS = new Set<String>{
        'Date_last_Invoice__c',
        'Core_CREFO_Status__c',
        'Core_New_Customer_Date__c',
        'Core_Lost_Customer_Date__c',
        'Last_external_Update_beDirect__c',
        'Validation_Self_Insurance__c',
        'Core_Founding_Date__c'
    };

    private final static Set<String> ACC_DATE_FIELDS = new Set<String>{ 
        'Last_Credit_Assessment__c' 
    };

    private final static Set<String> ACC_DECIMAL_FIELDS = new Set<String>{
        'Core_CREFO_Limit__c',
        'Core_CREFO_Annual_Sales__c',
        'Core_Credit_Limit__c',
        'Currently_outstanding_Positions__c',
        'Rating_BBI_Credit_Report_B_rgel_Index__c',
        'Not_invoiced_order_value__c',
        'Core_Contact_Data_EMail_Distribution_Inv__c'
    };

    private final static Set<String> ACC_WZCODES_RELATION_FIELDS = new Set<String>{
        'Core_WZ_Code_1__c',
        'Core_WZ_Code_2__c',
        'Core_WZ_Code_3__c',
        'Core_WZ_Code_4__c'
    };

    private final static Set<String> ACC_USER_RELATION_FIELDS = new Set<String>{
        'Large_Account_Manager__c',
        'Key_Account_Manager__c', 
        'Core_Commercial_Administrator__c'
    };

    private final static Set<String> ACC_SKIPPT_FIELDS = new Set<String>{
        'Contacts', // handled separately
        'Territory', // not implemented
        'Account_Checksum__c', //TODO
        'Contact_Checksum__c', //TODO
        'Territory_Checksum__c' //TODO
    };

    private final static Set<String> CONTA_BOOLEAN_ZERO_ONE_FIELDS = new Set<String>{
        'Revocation_Mailing__c',
        'Revocation_Direct_Mailing_Letter_Post__c',
        'Revocation_Newsletter__c'
    };

    private final static Set<String> CONTA_DATETIME_FIELDS = new Set<String>{
        'Date_of_Revocation_Mailing__c',
        'Date_of_Revocation_Direct_Mailing_Lett__c',
        'Date_of_Revocation_Newsletter__c'
    };

    private final static Set<String> CONTA_RESTRICTED_PICKLIST_FIELDS = new Set<String>{
        'Job_Title__c',
        'Expertise_Interest__c',
        'Title__c'
    };

    private static final String EMAIL = 'Core_Email__c';
    private static final String SOURCE_SYSTEM = 'Core_Source_System__c';
    private static final String GRACE = 'Grace';
    public static final String CLASSNAME = 'GRSYAccService';

    private Map<String,Core_Error_Log__c> errorLogs = new Map<String,Core_Error_Log__c>();
    private Map<String,Company_Group__c> companyGroupsMap = new Map<String,Company_Group__c>();
    private Map<String,Company_Key__c> companyKeysMap = new Map<String,Company_Key__c>();

    private GRSYAccHelper helper = new GRSYAccHelper();
    private TTRAccountHandler territoryHandler = new TTRAccountHandler();

    /**
     * Process incoming accounts in bulk within the custom change data capture interface.
     *
     * @param bulkSize to define how many records needs to be fetched in one call
     *
     * @return GRSYAccRESTResource.CDCResult
     */
    public GRSYAccRESTResource.CDCResult processCdcAccounts(Integer bulkSize) {
        List<Object> jsonArray = SHRGraceAPI.getCdcAccountsV1(bulkSize);
        System.debug('Number of fetched Accounts: ' + jsonArray.size());

        try {
            GRSYAccRESTResource.CDCResult cdcResult = new GRSYAccRESTResource.CDCResult();
            processJsonAccountArray(jsonArray, null);
            cdcResult.errors = this.errorLogs.values();
            cdcResult.errorRecords = this.errorLogs.values().size();
            cdcResult.processedRecords = jsonArray.size();
            return cdcResult;
        } catch (Exception e) {
            throw new GRSYAccServiceException(
                'Error during bulk processing. Account chunk size: ' +
                jsonArray.size() +
                '. Error-Message: ' +
                e.getMessage()
            );
        } finally {
            UTLCommons.debugLimits();
        }
    }

    /**
     * Convert incoming set of customer numbers to AccountIds
     *
     * @param customerNumbers customer numbers
     *
     * @return SHRGraceAPI.AccountIdList
     */
    public static SHRGraceAPI.AccountIdList mapCustomerNumbers(Set<String> customerNumbers) {
        SHRGraceAPI.AccountIdList accIdsList = new SHRGraceAPI.AccountIdList();
        accIdsList.accounts = new List<SHRGraceAPI.AccountsId>();
        for (String cuNumber : customerNumbers) {
            SHRGraceAPI.AccountsId accId = new SHRGraceAPI.AccountsId();
            accId.accountid = cuNumber;
            accIdsList.accounts.add(accId);
        }
        return accIdsList;
    }

    /**
     * Get SHRGRACEAPI response matching set of customer numbers and process incoming response
     *
     * @param customerNumbers list of customerNumbers
     */
    public void processAccountList(Set<String> customerNumbers) {
        SHRGraceAPI.AccountIdList accountIdList = mapCustomerNumbers(customerNumbers);
        
        List<Account> accList = [SELECT Id, Name, Core_Customer_Number__c, Total_Checksum__c FROM Account WHERE Core_Customer_Number__c IN :customerNumbers]; 
        Map<String,SObject> existingAccountsMappedByCustomerNumber = UTLCommons.mapByStringField(
                accList,
                Account.Core_Customer_Number__c
            );

        System.debug('Number of requested Accounts: ' + customerNumbers.size());
        List<Object> jsonArray = SHRGraceAPI.getAccountListV1(accountIdList);

        try {
            processJsonAccountArray(jsonArray, existingAccountsMappedByCustomerNumber);
        } catch (Exception e) {
            throw new GRSYAccServiceException(
                'Error during bulk processing. Account chunk size: ' +
                jsonArray.size() +
                '. Error-Message: ' +
                e.getMessage() +
                '. Line: ' + 
                e.getLineNumber() +
                '. TraceString: ' + 
                e.getStackTraceString() 
            );
        } finally {
            UTLCommons.debugLimits();
        }
    }

    /**
     * Process SHRGRACEAPI response into Accounts, Contacts, AccountContactRelations, match with existing Accounts, Contacts, AccountContactRelations,
     * upsert and update created data
     *
     * @param jsonArray SHRGRACEAPI response
     * @param existingAccountsMappedByCustomerNumber existing incoming accounts mapped by their customer number
     */
    private void processJsonAccountArray(
        List<Object> jsonArray, 
        Map<String,SObject> existingAccountsMappedByCustomerNumber
    ) {
        System.debug('Number of fetched Accounts: ' + jsonArray.size());

        /* Process Accounts */
        Map<String, Account> incomingAccsByCuNumber = new Map<String, Account>();
        Map<String, Account> incomingConvertedAccsByCuBumber = new Map<String, Account>();
        Map<String, List<Contact>> allIncomingContactsByCuNumber = new Map<String, List<Contact>>();
        //find existing WZ codes to prevent validation errors 
        Map<String, Core_WZ_Code__c> existingWZCodesbyExternalID = helper.getExistingWZCodes();
        //find ad names of active account managers to prevent validation errors
        Map<String,String> activeAccManagerADNamesbyLowerCase = helper.getActiveAccManagerADNamesbyLowerCase();
        //find all existing fields for Account and Contact to match with incoming fields
        Set<String> accountObjectFields = Schema.SObjectType.Account.fields.getMap().keySet();
        Set<String> contactObjectFields = Schema.SObjectType.Contact.fields.getMap().keySet();
        //handle territories 
        Map<String, List<SHRGraceAPI.SalesUnit>> externalTerritoriesByAccountCuNumbers = new Map<String, List<SHRGraceAPI.SalesUnit>>();

        // find existing accounts that needs to be converted (their customer number must be replaced)
        Map<String, Account> convertedAccountByOldCuNos = helper.filterExistingAccountIdsMatchOldCuNumber(jsonArray);
        System.debug(convertedAccountByOldCuNos.keySet().size() + ' converted accounts are in current response');
        Set<Id> externalIds = new Set<Id>();

        //track all incoming contacts 
        Set<String> allIncomingContactPersonIDs = new Set<String>();
        
        for (Object jsonAccountItem : jsonArray) {
            // get Single Account JSON-Object
            Map<String, Object> jsonAcc = (Map<String, Object>) jsonAccountItem;

            // get Customer-Number to refer related objects
            String currentCuNumber = (String) jsonAcc.get('Core_Customer_Number__c');
            String oldCuNumber = (String) jsonAcc.get('Old_Customer_Number__c');
            String checkSum = (String) jsonAcc.get('Total_Checksum__c');

            //only update account if its values were changed 
            if(existingAccountsMappedByCustomerNumber != null){
                Account existingAccount = (Account) existingAccountsMappedByCustomerNumber.get(currentCuNumber);

                if (existingAccount != null){
                    //compare checksum to see if account values were changed 
                    if(existingAccount.Total_Checksum__c == checkSum){
                        //if checksum is not changed, don't update account
                        System.debug(
                            LoggingLevel.FINE,
                            'Check sum is not different, Account ' + currentCuNumber + ' will be skipped in update'
                        );
                        continue; 
                    }
                }else{
                    //for Accounts that do not yet exist, set the Core Source System field
                    jsonAcc.put('Core_Source_System__c','Grace');

                }
            }

            // map Contacts and associate with Accounts
            List<Object> jsonContact = (List<Object>) jsonAcc.get('Contacts');
            List<Contact> incomingContacts = mapContacts(jsonContact, contactObjectFields);
            //store person Ids of incoming contacts in set for further processing
            for(Contact con : incomingContacts){
                allIncomingContactPersonIDs.add(con.PersonID__c);
            }
            allIncomingContactsByCuNumber.put(currentCuNumber, incomingContacts);

            //store territories
            List<SHRGraceAPI.SalesUnit> accountTerritories = (List<SHRGraceAPI.SalesUnit>) JSON.deserialize(
                JSON.serialize(jsonAcc.get('Territory')),
                List<SHRGraceAPI.SalesUnit>.class
            );
            if(accountTerritories?.size() > 0){
                externalTerritoriesByAccountCuNumbers.put(currentCuNumber, accountTerritories);
            }

            //store Company Group 
            Object companyGroupObject = jsonAcc.get('Companygroup');
            if(companyGroupObject != null){
                List<Object> companyGroupList = (List<Object>) companyGroupObject;
                for(Object companyGroup : companyGroupList){
                    Map<String, Object> jsonCompG = (Map<String, Object>) companyGroup;
                    Company_Group__c compGroup = mapCompanyGroupFields(jsonCompG, activeAccManagerADNamesbyLowerCase);
                    this.companyGroupsMap.put(compGroup.Company_Group_ID__c, compGroup);
                }
            }

            //store Company Key 
            Object companyKeyObject = jsonAcc.get('Companykey');
            if(companyKeyObject != null){
                List<Object> companyKeyList = (List<Object>) companyKeyObject;
                for(Object companyKey : companyKeyList){
                    Map<String, Object> jsonComp = (Map<String, Object>) companyKey;
                    Company_Key__c compKey = mapCompanyKeyFields(jsonComp);
                    this.companyKeysMap.put(compKey.Company_Key_ID__c, compKey);
                }
            }   

            // map Accounts
            Account externalAccount = mapAccountFields(jsonAcc, existingWZCodesbyExternalID, accountObjectFields, activeAccManagerADNamesbyLowerCase);

            // separate converted accounts from ordinary accounts
            if (convertedAccountByOldCuNos.containsKey(oldCuNumber)) {
                Account existingAccountNowConverted = convertedAccountByOldCuNos.get(oldCuNumber);
                //check if existing Account was already converted in the same process
                if(!externalIds.contains(existingAccountNowConverted.Id)){
                    //override customer number for existing account
                    externalAccount.Id = existingAccountNowConverted.Id;
                    incomingConvertedAccsByCuBumber.put(currentCuNumber, externalAccount);
                    externalIds.add(existingAccountNowConverted.Id);
                }
                else{
                    incomingAccsByCuNumber.put(currentCuNumber, externalAccount);
                }   
            } else {
                incomingAccsByCuNumber.put(currentCuNumber, externalAccount);
            }
        }
 
        //upsert all incoming company keys and company groups to avoid lookup errors on accounts
        if (!companyGroupsMap.isEmpty()) {
            upsertSObjAndCreateErrorLogs(this.companyGroupsMap.values(), Company_Group__c.Company_Group_ID__c);
        }

        if (!companyKeysMap.isEmpty()) {
            upsertSObjAndCreateErrorLogs(companyKeysMap.values(), Company_Key__c.Company_Key_ID__c);
        }

        // group all all incoming Accounts for further handling
        Map<String, Account> allIncomingAccounts = new Map<String, Account>();
        allIncomingAccounts.putAll(incomingConvertedAccsByCuBumber);
        allIncomingAccounts.putAll(incomingAccsByCuNumber);

        // update converted Accounts and their Customer Numbers
        updateSObjAndCreateErrorLogs(incomingConvertedAccsByCuBumber.values());
        // upsert accounts
        upsertSObjAndCreateErrorLogs(incomingAccsByCuNumber.values(), Account.Core_Customer_Number__c);
        
        System.debug(LoggingLevel.INFO, incomingConvertedAccsByCuBumber.keySet().size() + ' converted accounts were updated');
        System.debug(LoggingLevel.INFO, incomingAccsByCuNumber.keySet().size() + ' accounts were upserted');
        System.debug(LoggingLevel.INFO, this.errorLogs.size() + ' errorlogs were created');

        // only accounts that are already stored can be processed further.
        // query existing records for further processing + accountcontactrelations
        Map<Id,Account> existingAccountsbyID = new Map<Id,Account>([SELECT Id, Core_Customer_Number__c FROM Account WHERE Core_Customer_Number__c IN :allIncomingAccounts.keySet()]);
        System.debug(LoggingLevel.INFO, existingAccountsbyID.values().size() + ' accounts have been saved or already exist');

        Map<String, SObject> existingAccountsByCuNumber = UTLCommons.mapByStringField(
            existingAccountsbyID.values(),
            Account.Core_Customer_Number__c
        );

        //Fetch all AccountContactRelations of existing Accounts
        Map<String, AccountContactRelation> accountRelationsByAccountContactId = helper.getExistingAccountContactRelation(
            existingAccountsbyID.values()
        );
        Map<String, List<AccountContactRelation>> accountRelationsByAccountId = helper.getExistingAccountRelations(
            existingAccountsbyID.values()
        );
        //Fetch all AccountContactRelations of existing Contacts
        Map<String, List<AccountContactRelation>> accountRelationsByContactId = helper.getExistingAccountContactRelationsbyContact(
            allIncomingContactPersonIDs
        );
        //Fetch all territories of existing Accounts
        List<ObjectTerritory2Association> objectTerritory2AssociationToRemove = this.territoryHandler.filterObjectTerritory2AssociationToRemove(
            existingAccountsbyID
        );

        // Process Contacts
        // Fetch all Contact-PersonIds from Org to match the incoming with the existing ones
        Set<String> existingPersonIds = new Set<String>();
        if (!existingAccountsbyID.isEmpty()) {
            existingPersonIds = helper.filterExistingPersonIdsMatchByIncomingPersonIds(jsonArray);
        }

        // the following records gets collected for debugging purposes associated with the Account
        Map<String, List<Contact>> newIncomingContactsByCuNo = new Map<String, List<Contact>>();
        Map<String, List<Contact>> editedIncomingContactByCuNo = new Map<String, List<Contact>>();
        Map<String, List<AccountContactRelation>> newIncomingContactRelationsByCuNo = new Map<String, List<AccountContactRelation>>();
        Map<String, List<AccountContactRelation>> convertedIncomingContactRelationsByCuNo = new Map<String, List<AccountContactRelation>>();

        // collecting variables
        List<Contact> allNewIncomingContacts = new List<Contact>();
        Set<String> allNewIncomingContactsIds = new Set<String>();
        List<Contact> allEditedIncomingContact = new List<Contact>();
        List<AccountContactRelation> allNewIncomingContactRelations = new List<AccountContactRelation>();
        List<AccountContactRelation> allConvertedIncomingContactRelations = new List<AccountContactRelation>();

        for (String accountCustomerNumber : existingAccountsByCuNumber.keySet()) {
            // get the current external Account
            Account externalAccount = allIncomingAccounts.get(accountCustomerNumber);
            // get the current Accounts accountContactRelations
            List<AccountContactRelation> accConRelationList = accountRelationsByAccountId.get(externalAccount.Id);
            // get the current external Contacts associated with the Account
            List<Contact> incomingContactsFromCurrentAcc = allIncomingContactsByCuNumber.get(accountCustomerNumber);

            // collections to associate wit the account
            List<Contact> newIncomingContacts = new List<Contact>();
            List<Contact> editedIncomingContact = new List<Contact>();
            List<AccountContactRelation> newIncomingContactRelations = new List<AccountContactRelation>();
            List<AccountContactRelation> convertedIncomingContactRelations = new List<AccountContactRelation>();

            System.debug(LoggingLevel.FINE, 'Processing Contacts for Account: ' + accountCustomerNumber);
            for (Contact contactOfCurrentAcc : incomingContactsFromCurrentAcc) {
                String externalPersonId = contactOfCurrentAcc.PersonID__c;
                String mapID = externalAccount.Id + contactOfCurrentAcc.PersonID__c;

                //get the AccountContactRelation of the current account + contact combination
                AccountContactRelation accRelation = accountRelationsByAccountContactId.get(mapID);
                List<AccountContactRelation> accConRelations = accountRelationsByContactId.get(contactOfCurrentAcc.PersonID__c);

                // check if contact already exists or has been checked before
                if ((existingPersonIds.contains(externalPersonId)) || (allNewIncomingContactsIds.contains(externalPersonId))) {
                    //Remove Core_Source_System__c field of Contact to avoid update on Contact record if it already exists
                    Map<String, Object> fieldsContact = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(contactOfCurrentAcc));
                    fieldsContact.remove('Core_Source_System__c');
                    contactOfCurrentAcc = (Contact) JSON.deserialize(JSON.serialize(fieldsContact), Contact.class);

                    //check if AccountContactRelation already exists between current external Account + current external Contact
                    if (accRelation != null) {
                        //update externalID, Role and Department of existing AccountContactRelation
                        accRelation = updateAccContactRelation(accRelation, externalAccount, contactOfCurrentAcc);
                        
                        if (!accRelation.IsDirect) {
                            //Remove Job_Title__c and Department__c fields of Contact to avoid update on Contact record if existing AccountContactRelation isn't direct
                            Map<String, Object> fields = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(contactOfCurrentAcc));
                            fields.remove('Job_Title__c');
                            fields.remove('Department__c');
                            contactOfCurrentAcc = (Contact) JSON.deserialize(JSON.serialize(fields), Contact.class);
                            //for non direct contacts, if they're marked with a deletion code it means the ACR should receive
                            //a deletion code, not the contact itself
                            if(contactOfCurrentAcc.Deletion_Code__c){
                                contactOfCurrentAcc.Deletion_Code__c = false;
                                accRelation.Deletion_Code__c = true; 
                            }
                        }
                        else{
                             //if ACR is direct, for Contacts with deletion code check if other ACR exist
                            if(contactOfCurrentAcc.Deletion_Code__c){
                                if(accConRelations?.size() > 1){
                                    //if yes, mark other ACR as direct and remove deletion code on contact
                                    for(AccountContactRelation accRelat : accConRelations){
                                        if(externalAccount.Id != accRelat.AccountId){
                                            contactOfCurrentAcc.AccountId = accRelat.AccountId;
                                            contactOfCurrentAcc.Deletion_Code__c = false;
                                            break;
                                        } 
                                    }
                                    //mark existing ACR as deleted 
                                    accRelation.Deletion_Code__c = true; 
                                }
                                else{
                                    //if not -> deletion code for ACR + Contact  
                                    accRelation.Deletion_Code__c = true; 
                                } 
                            }
                        }
                        convertedIncomingContactRelations.add(accRelation);
                    } else {
                        //create new AccountContactRelation
                        AccountContactRelation newAccountContactRelation = createAccContactRelation(externalAccount,contactOfCurrentAcc);
                        
                        //Remove Job_Title__c and Department__c fields of Contact to avoid update on Contact record if other AccountContactRelations already exist
                        if (accConRelationList != null) {
                            Map<String, Object> fields = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(contactOfCurrentAcc));
                            fields.remove('Job_Title__c');
                            fields.remove('Department__c');
                            contactOfCurrentAcc = (Contact) JSON.deserialize(JSON.serialize(fields), Contact.class);
                            //for non direct contacts, which is assumed as other ACRs exist, if they're marked with 
                            //a deletion code it means the ACR should receive a deletion code, not the contact itself
                            if(contactOfCurrentAcc.Deletion_Code__c){
                                contactOfCurrentAcc.Deletion_Code__c = false;
                                newAccountContactRelation.Deletion_Code__c = true; 
                            }
                        }
                        newIncomingContactRelations.add(newAccountContactRelation);
                    }
                    // the contact is also updated
                    editedIncomingContact.add(contactOfCurrentAcc);
                } else {
                    // new Contact is always direct
                    contactOfCurrentAcc.AccountId = existingAccountsByCuNumber.get(accountCustomerNumber).Id;
                    newIncomingContacts.add(contactOfCurrentAcc);
                    allNewIncomingContactsIds.add(externalPersonId);
                }
            }

            newIncomingContactsByCuNo.put(accountCustomerNumber, newIncomingContacts);
            editedIncomingContactByCuNo.put(accountCustomerNumber, editedIncomingContact);
            newIncomingContactRelationsByCuNo.put(accountCustomerNumber, newIncomingContactRelations);
            convertedIncomingContactRelationsByCuNo.put(accountCustomerNumber, convertedIncomingContactRelations);

            System.debug(
                LoggingLevel.FINE, 
                newIncomingContacts.size() + ' Contacts will be created, ' + editedIncomingContact.size() + ' will be updated. Related to Acc: ' + accountCustomerNumber);
            System.debug(
                LoggingLevel.FINE,
                newIncomingContactRelations.size() +' AccRelations will be created, ' + convertedIncomingContactRelations.size() + ' will be updated. Related to Acc: ' + accountCustomerNumber);
            
            allNewIncomingContacts.addAll(newIncomingContacts);
            allEditedIncomingContact.addAll(editedIncomingContact);
            allNewIncomingContactRelations.addAll(newIncomingContactRelations);
            allConvertedIncomingContactRelations.addAll(convertedIncomingContactRelations);
        }
        if (!allNewIncomingContacts.isEmpty()) {
            // group all to avoide duplicate external ids
            Map<String, Contact> allNewIncomingContactsByPersId = (Map<String, Contact>) UTLCommons.mapByStringField(
                allNewIncomingContacts,
                Contact.PersonID__c
            );
            System.debug('New external Contacts getting upserted: ' + String.join((Iterable<String>) allNewIncomingContactsByPersId.keySet(), ','));
            //upsert all new contacts
            upsertSObjAndCreateErrorLogs(allNewIncomingContactsByPersId.values(), Contact.PersonID__c);
        }
        if (!allEditedIncomingContact.isEmpty()) {
            // group all to avoide duplicate external ids
            Map<String, Contact> allEditedIncomingContactByPersId = (Map<String, Contact>) UTLCommons.mapByStringField(
                allEditedIncomingContact,
                Contact.PersonID__c
            );
            System.debug('Edited external Contacts getting upserted: ' + String.join((Iterable<String>) allEditedIncomingContactByPersId.keySet(), ','));
            //update all existing contacts
            upsertSObjAndCreateErrorLogs(allEditedIncomingContactByPersId.values(), Contact.PersonID__c);
        }
        if (!allNewIncomingContactRelations.isEmpty()) {
            // group all to avoide duplicate external ids
            Map<String, AccountContactRelation> allNewIncomingContactRelationsByExtId = (Map<String, AccountContactRelation>) UTLCommons.mapByStringField(
                allNewIncomingContactRelations,
                AccountContactRelation.External_ID__c
            );
            System.debug('New ContactRelations getting upserted ' + String.join((Iterable<String>) allNewIncomingContactRelationsByExtId.keySet(), ','));
            //upsert all new AccountContactRelations
            upsertSObjAndCreateErrorLogs(allNewIncomingContactRelationsByExtId.values(),AccountContactRelation.External_ID__c);
        }
        if (!allConvertedIncomingContactRelations.isEmpty()) {
            // group all to avoide duplicate external ids
            Map<String, AccountContactRelation> allConvertedIncomingContactRelationsByExtId = (Map<String, AccountContactRelation>) UTLCommons.mapByStringField(
                allConvertedIncomingContactRelations,
                AccountContactRelation.External_ID__c
            );
            System.debug('ContactRelations getting updated ' + String.join((Iterable<String>) allConvertedIncomingContactRelationsByExtId.keySet(), ','));
            //update all existing AccountContactRelations
            updateSObjAndCreateErrorLogs(allConvertedIncomingContactRelationsByExtId.values());
        }
        if (!objectTerritory2AssociationToRemove.isEmpty()) {
            // delete all existing ObjectTerritory2Associations Accounts
            delete objectTerritory2AssociationToRemove;
        }
        if (!externalTerritoriesByAccountCuNumbers.isEmpty()) {
            // create new ObjectTerritory2Associations for Accounts
            insert this.territoryhandler.filterObjectTerritory2AssociationToCreate(externalTerritoriesByAccountCuNumbers);
        }
        if (!this.errorLogs.isEmpty()) {
            UTLErrorLog.upsertErrorLogs(this.errorLogs.values(), null, CLASSNAME);
        }
    }

    /**
     * Map fields of incoming json response with Account fields to create Account record
     *
     * @param jsonAcc Account in json response
     * @param existingWZCodesbyExternalID All WZ codes existing in the org matched by their external ID
     * @param accountObjectFields All fields existing for the Object Account in the org 
     * @param activeAccManagerADNamesbyLowerCase All existing active users with ad names
     *
     * @return Account
     */
    private Account mapAccountFields(Map<String, Object> jsonAcc, Map<String, Core_WZ_Code__c> existingWZCodesbyExternalID, Set<String> accountObjectFields, Map<String,String> activeAccManagerADNamesbyLowerCase) {
        Account account = new Account();

        for (String fieldName : jsonAcc.keySet()) {
            // get the current field Name
            Object value = jsonAcc.get(fieldName);
                /*  Handle null/empty values */
                if (ACC_BOOLEAN_ZERO_ONE_FIELDS.contains(fieldName)) {
                    // integer-boolean 1 | 0 fields
                    account.put(fieldName, value == '1' ? true : false);
                } else if (ACC_SKIPPT_FIELDS.contains(fieldName)) {
                    // do nothing
                    continue; 
                } else if (fieldName == SOURCE_SYSTEM) {
                    account.put(fieldName, value);
                } else if (String.isBlank(String.valueOf(value))) {
                    // set account value to null if json field is empty
                    account.put(fieldName, null);
                } else if (ACC_DECIMAL_FIELDS.contains(fieldName)) {
                    // double or currency fields
                    value = Decimal.valueOf(String.valueOf(value));
                    account.put(fieldName, value);
                } else if (ACC_DATETIME_FIELDS.contains(fieldName)) {
                    // datetime fields
                    value = UTLCommons.convertISO8601(String.valueOf(value));
                    account.put(fieldName, value);
                } else if (ACC_DATE_FIELDS.contains(fieldName)) {
                    // date fields
                    value = Date.valueOf(String.valueOf(value));
                    account.put(fieldName, value);
                } else if (ACC_WZCODES_RELATION_FIELDS.contains(fieldName)) {
                    //check if WZ Code exists in org, only create lookup for existing codes
                    if(existingWZCodesbyExternalID.containsKey(String.valueOf(value))){
                        account.putSObject(
                            fieldName.replace('__c', '__r'),
                            new Core_WZ_Code__c(Core_WZ_Code_ID__c = String.valueOf(value))
                        );
                    }
                    else{
                        //create error log for wz codes that don't exist but don't prevent account import
                        Core_Error_Log__c errorLog = UTLErrorLog.createErrorLogRecord(
                            CLASSNAME, null, 
                            'Error during upsert of Account. Error-Code: Core_WZ_Code_ID__c not found', 
                            null, GRACE, true, String.valueOf(value), 
                            'Error during upsert of Account. Foreign key external ID ' + String.valueOf(value) + ' not found for field Core_WZ_Code_ID__c in entity Core_WZ_Code__c.');
                            this.errorLogs.put(errorLog.Core_Checksum__c, errorLog);
                     }
                } else if (fieldName == 'Company_Group__c') {
                    account.putSObject(
                        fieldName.replace('__c', '__r'),
                        new Company_Group__c(Company_Group_ID__c = String.valueOf(value))
                    );
                } else if (fieldName == 'Company_Key__c') {
                    account.putSObject(
                        fieldName.replace('__c', '__r'),
                        new Company_Key__c(Company_Key_ID__c = String.valueOf(value))
                    );
                    /*  Handle user lookups */
                } else if (ACC_USER_RELATION_FIELDS.contains(fieldName)) {
                    String externalManagerName = String.valueOf(value);
                    // if managername exists in org create lookup, else set null
                    account.putSObject(
                        fieldName.replace('__c', '__r'),
                        activeAccManagerADNamesbyLowerCase.keySet().contains(externalManagerName.toLowerCase())
                            ? new User(AD_Login_Name__c = activeAccManagerADNamesbyLowerCase.get(externalManagerName.toLowerCase()))
                            : null
                    );
                    /* handle special Fields */
                }  else if (fieldName == EMAIL) {
                    Boolean isMailValid = UTLCommons.validateEmail(String.valueOf(value));
                    account.put(fieldName, isMailValid ? value : null);
                } else {
                    /*  Handle all primitives, like strings and json-boolean */
                    //check if field exists
                    if(accountObjectFields.contains(fieldName.toLowerCase())) {
                        account.put(fieldName, value);
                    }
                    else{
                        System.debug(LoggingLevel.FINEST, 'Error: Account mapping:' + fieldName + ' : ' + value + ' was unsucessful: ' + fieldName + 'does not exist on Account.');
                        continue;
                    }
                }
                System.debug(LoggingLevel.FINEST, 'Account mapping:' + fieldName + ' : ' + value);
            }

        return account;
    }

    /**
     * Map fields of incoming json response with Company Key fields to create Company Key record
     *
     * @param jsonComp Company Key in json response
     *
     * @return Company Key record
     */
    private Company_Key__c mapCompanyKeyFields(Map<String, Object> jsonComp) {
        Company_Key__c compKey = new Company_Key__c();

        for (String fieldName : jsonComp.keySet()) {
            Object value = jsonComp.get(fieldName);

            if (fieldName == 'Company_Group__c') {
                    compKey.putSObject(
                        fieldName.replace('__c', '__r'),
                        new Company_Group__c(Company_Group_ID__c = String.valueOf(value))
                    );
            } else if (fieldName == 'Company_Key_ID__c' || fieldName == 'Name' || fieldName == 'Payment_Terms__c') {
                compKey.put(fieldName, String.valueOf(value));
            } 
        }

        return compKey;
    }

    /**
     * Map fields of incoming json response with Company Group fields to create Company Group record
     *
     * @param jsonComp Company Group in json response
     * @param activeAccManagerADNamesbyLowerCase All existing active users with ad names
     *
     * @return Company Group record
     */
    private Company_Group__c mapCompanyGroupFields(Map<String, Object> jsonComp, Map<String,String> activeAccManagerADNamesbyLowerCase) {
        Company_Group__c compGroup = new Company_Group__c();

        for (String fieldName : jsonComp.keySet()) {
            // get the current field Name
            Object value = jsonComp.get(fieldName);
                /*  Handle null/empty values */
                if (fieldName == 'Company_Group_ID__c' || fieldName == 'Name' || fieldName == 'Payment_Terms__c') {
                    compGroup.put(fieldName, String.valueOf(value));
                } else if (fieldName == 'Account_Manager__c') {
                    String externalManagerName = String.valueOf(value);
                    // if managername exists in org create lookup, else set null
                    compGroup.putSObject(
                        fieldName.replace('__c', '__r'),
                        activeAccManagerADNamesbyLowerCase.keySet().contains(externalManagerName.toLowerCase())
                            ? new User(AD_Login_Name__c = activeAccManagerADNamesbyLowerCase.get(externalManagerName.toLowerCase()))
                            : null
                    );
                } else if (fieldName == 'Key_Account__c' || fieldName == 'Large_Account__c') {
                    compGroup.put(fieldName, value);
                } 
            }

        return compGroup;
    }

    /**
     * Split incoming array of Contacts to handle one at a time
     * 
     * @param contactJsonArray Incoming JSON Array of Contacts
     * @param contactObjectFields All fields existing for Object Contact in the org
     * 
     * @return list of generated contacts from incoming JSON
     */
    private List<Contact> mapContacts(List<Object> contactJsonArray, Set<String> contactObjectFields) {
        List<Contact> externalContacts = new List<Contact>();
        for (Object contactJsonItem : contactJsonArray) {
            Contact contact = mapContact((Map<String, Object>) contactJsonItem, contactObjectFields);
            externalContacts.add(contact);
        }
        return externalContacts;
    }

    /**
     * Map fields of incoming json response with Contact fields to create Contact record
     * 
     * @param jsonContact Contact in json response
     * @param contactObjectFields All fields existing for Object Contact in the org
     * 
     * @return generated contact from incoming JSON
     */
    private Contact mapContact(Map<String, Object> jsonContact, Set<String> contactObjectFields) {
        Contact contact = new Contact();
        System.debug(LoggingLevel.FINEST, 'Contact mapping starts ------------------------------------------------ ');
        for (String fieldName : jsonContact.keySet()) {
            Object value = jsonContact.get(fieldName);

            if (fieldName == 'FirstName') {
                String firstName = String.valueOf(value);
                contact.put(fieldName, String.isBlank(firstName) ? 'N/A' : value);
            } else if (CONTA_BOOLEAN_ZERO_ONE_FIELDS.contains(fieldName)) {
                // integer-boolean 1 | 0 fields
                contact.put(fieldName, value == '1' ? true : false);
            } else if (String.isBlank(String.valueOf(value))) {
                if(contactObjectFields.contains(fieldName.toLowerCase())) {
                    // set contact value to null if json field is empty
                    contact.put(fieldName, null);
                }
                else{
                    System.debug(LoggingLevel.FINEST, 'Error: Contact mapping:' + fieldName + ' : ' + value + ' was unsucessful: ' + fieldName + 'does not exist on Contact.');
                    continue;
                }
            } else if (CONTA_DATETIME_FIELDS.contains(fieldName)) {
                // datetime fields
                value = UTLCommons.convertISO8601(String.valueOf(value));
                contact.put(fieldName, value);
            } else if (CONTA_RESTRICTED_PICKLIST_FIELDS.contains(fieldName)) {
                //value 42 is missing for Title picklist and has to be replaced
                if(fieldName == 'Title__c' && value == '42'){
                    value = '0';
                }
                //restricted picklists that can't handle 0 value
                contact.put(fieldName, value == '0' ? null : value);
            } else if (fieldName == EMAIL) {
                Boolean isMailValid = UTLCommons.validateEmail(String.valueOf(value));
                contact.put(fieldName, isMailValid ? value : null);
            } else {
                if(contactObjectFields.contains(fieldName.toLowerCase())) {
                    contact.put(fieldName, value);
                }
                else{
                    System.debug(LoggingLevel.FINEST, 'Error: Contact mapping:' + fieldName + ' : ' + value + ' was unsucessful: ' + fieldName + 'does not exist on Contact.');
                    continue;
                }
            }
            contact.OwnerId = helper.getIntegrationUserId();
            System.debug(LoggingLevel.FINEST, 'Contact mapping:' + fieldName + ' : ' + value);
        }

        /* handle missing fields */
        if (String.isBlank(String.valueOf(contact.get(SOURCE_SYSTEM)))) {
            contact.put(SOURCE_SYSTEM, GRACE);
        }

        return contact;
    }

    /**
     * Create new AccountContactRelation
     *
     * @param account Account
     * @param contact Contact
     *
     * @return AccountContactRelation created between Account + Contact
     */
    public AccountContactRelation createAccContactRelation(Account account, Contact contact) {
        AccountContactRelation accContaRelation = new AccountContactRelation();
        accContaRelation.External_ID__c = account.Core_Customer_Number__c + '_' + contact.PersonID__c;
        accContaRelation.Account = new Account(Core_Customer_Number__c = account.Core_Customer_Number__c);
        accContaRelation.Contact = new Contact(PersonID__c = contact.PersonID__c);
        accContaRelation.Role__c = contact.Job_Title__c;
        accContaRelation.Department__c = contact.Department__c;
        return accContaRelation;
    }

    /**
     * Update AccountContactRelation in case Account is converted or Job_Title__c and Department__c on Contact was changed
     *
     * @param accContaRelation numbers AccountContactRelation to update
     * @param account Account for Core_Customer_Number__c
     * @param contact Contact for PersonID__c, Job_Title__c, Department__c
     *
     * @return updated AccountContactRelation with Account + Contact attributes
     */
    public AccountContactRelation updateAccContactRelation(
        AccountContactRelation accContaRelation,
        Account account,
        Contact contact
    ) {
        accContaRelation.External_ID__c = account.Core_Customer_Number__c + '_' + contact.PersonID__c;
        accContaRelation.Role__c = contact.Job_Title__c;

        if (contact.Department__c != null) {
            accContaRelation.Department__c = contact.Department__c;
        }
        return accContaRelation;
    }

    /**
     * Update list of sObjects, create error logs on returned Database.SaveResult
     *
     * @param sObjects list of sObjects to update
     */
    private void updateSObjAndCreateErrorLogs(List<SObject> sObjects) {
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.duplicateRuleHeader.allowSave = true;
        dmlOptions.optAllOrNone = false;

        List<Database.SaveResult> updateResults = Database.update(sObjects, dmlOptions);
        List<UTLCommons.DatabaseResult> databaseResults = UTLCommons.mapDatabaseResultList(updateResults);
        createErrorLogs(databaseResults, sObjects, 'update');
    }

    /**
     * Upsert list of sObjects, create error logs on returned Database.UpsertResult
     *
     * @param sObjects list of sObjects to upsert
     * @param externalId the external id Field
     */
    private void upsertSObjAndCreateErrorLogs(
        List<SObject> sObjects,
        SObjectField externalId
    ) {
        List<Database.UpsertResult> upsertResults = Database.upsert(sObjects, externalId, false);
        List<UTLCommons.DatabaseResult> databaseResults = UTLCommons.mapDatabaseResultList(upsertResults);
        createErrorLogs(databaseResults, sObjects, 'upsert');
    }

    /**
     * Create error logs from Database results
     *
     * @param databaseResults results from either upsert or update operation
     * @param sObjects list of sObjects that were upserted / updated
     * @param operation type of operation that was performed, either upsert or update
     */
    private void createErrorLogs(
        List<UTLCommons.DatabaseResult> databaseResults,
        List<SObject> sObjects,
        String operation
    ) {
        for (Integer i = 0; i < databaseResults.size(); i++) {
            if (databaseResults[i].isError()) {
                for (Database.Error error : databaseResults[i].getErrors()) {
                    Core_Error_Log__c errorLog = UTLErrorLog.createErrorLogRecord(
                        CLASSNAME, null, 
                        'Error during ' + operation + ' of ' + sObjects[i].getSObjectType().getDescribe().getName() + '. Error-Code: ' + error.getStatusCode().name(), 
                        databaseResults[i].getId(), GRACE, true, getExternalIdFieldValue(sObjects[i]), UTLCommons.parseDbErrorMessage(error));
                        this.errorLogs.put(errorLog.Core_Checksum__c, errorLog);
                }
            }
        }
    }

    /**
     * Get Id from sObj, depending on wether it's an AccountId, ContactId, or general externalId
     *
     * @param sObj to get ID from
     *
     * @return external ID of sObj
     */
    private String getExternalIdFieldValue(SObject sObj) {
        String typeName = sObj.getSObjectType().getDescribe().getName();
        if (typeName == 'Account') {
            return String.valueOf(sObj.get('Core_Customer_Number__c'));
        } else if (typeName == 'Contact') {
            return String.valueOf(sObj.get('PersonID__c'));
        } else if (typeName == 'Company_Group__c') {
            return String.valueOf(sObj.get('Company_Group_ID__c'));
        } else if (typeName == 'Company_Key__c') {
            return String.valueOf(sObj.get('Company_Key_ID__c'));
        } else {
            // 'AccountContactRelation'
            return String.valueOf(sObj.get('External_ID__c'));
        }
    }

    private class GRSYAccServiceException extends Exception {
    }
}