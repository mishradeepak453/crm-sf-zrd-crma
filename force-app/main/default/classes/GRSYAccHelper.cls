/**
 * SF-911 Account-Sync mittels Grace-Aufruf
 * Utility functionalities for Account Sync.
 *
 * @group GRSY - Grace Sync Account
 * @date 30.06.2022
 * @author daniel.gette@zepplin.com
 */
public with sharing class GRSYAccHelper {
    private static User integrationUser;
    private static Map<String,String> activeAccManagerADNamesbyLowerCase;

    public GRSYAccHelper() {
        if (integrationUser == null) {
            integrationUser = [SELECT Id FROM User WHERE FirstName = 'Integration' AND LastName = 'User'];
        }
        if (activeAccManagerADNamesbyLowerCase == null) {
            Map<String,String> mapActiveAccManagerADNamesbyLowerCase = new Map<String,String>();
            List<User> accountManagerList = new List<User>(
                [SELECT AD_Login_Name__c FROM User WHERE AD_Login_Name__c != NULL AND IsActive = TRUE]
            );

            for(User us : accountManagerList){
                mapActiveAccManagerADNamesbyLowerCase.put(us.AD_Login_Name__c.toLowerCase(),us.AD_Login_Name__c);
            }
            activeAccManagerADNamesbyLowerCase = mapActiveAccManagerADNamesbyLowerCase;
        }
    }

    public Id getIntegrationUserId() {
        return integrationUser.Id;
    }

    public Map<String,String> getActiveAccManagerADNamesbyLowerCase() {
        return activeAccManagerADNamesbyLowerCase;
    }

    /**
     * Get all existing Accounts that should be converted according to the json response
     * by querying for Accounts with Core Customer Numbers set as Old Customer Numbers in the incoming response
     *
     * @param jsonArray incoming json response
     *
     * @return to be converted Accounts mapped with their Core Customer Numbers
     */
    public Map<String, Account> filterExistingAccountIdsMatchOldCuNumber(List<Object> jsonArray) {
        Set<String> oldCuNumbers = new Set<String>();
        for (Object jsonItem : jsonArray) {
            Map<String, Object> jsonAcc = (Map<String, Object>) jsonItem;
            String oldCustomerNumber = (String) jsonAcc.get('Old_Customer_Number__c');
            oldCuNumbers.add(oldCustomerNumber);
        }

        //only convert accounts that are still of type prospect and not marked with deletion code
        List<Account> convertedAccount = [
            SELECT Id, Core_Customer_Number__c
            FROM Account
            WHERE Core_Customer_Number__c IN :oldCuNumbers
            AND Core_Customer_Type__c = '7' 
        ];

        Map<String, Account> conversionCandidateAccsByOldCuNos = new Map<String, Account>();
        if (!convertedAccount.isEmpty()) {
            conversionCandidateAccsByOldCuNos = (Map<String, Account>) UTLCommons.mapByStringField(
                convertedAccount,
                Account.Core_Customer_Number__c
            );
        }
        return conversionCandidateAccsByOldCuNos;
    }

     /**
     * Get all existing WZ Codes
     *
     * @return existing WZ Codes mapped by their external ID 
     */
    public Map<String, Core_WZ_Code__c> getExistingWZCodes() {

        List<Core_WZ_Code__c> existingWZCodes = [
            SELECT Id, Core_WZ_Code_ID__c
            FROM Core_WZ_Code__c
        ];

        Map<String, Core_WZ_Code__c> existingWZCodesbyExternalID = new Map<String, Core_WZ_Code__c>();
        if (!existingWZCodes.isEmpty()) {
            existingWZCodesbyExternalID = (Map<String, Core_WZ_Code__c>) UTLCommons.mapByStringField(
                existingWZCodes,
                Core_WZ_Code__c.Core_WZ_Code_ID__c
            );
        }
        return existingWZCodesbyExternalID;
    }

    /**
     * Get all existing AccountContactRelations for incoming Accounts
     *
     * @param accountList incoming Accounts
     *
     * @return existing AccountContactRelations mapped with String combining the account's AccountId and contact's Contact_Person_ID__c
     */
    public Map<String, AccountContactRelation> getExistingAccountContactRelation(List<Account> accountList) {
        Map<String, AccountContactRelation> accountRelationsByAccountContactId = new Map<String, AccountContactRelation>();

        for (AccountContactRelation accrelation : [
            SELECT Id, AccountId, Contact_Person_ID__c, External_ID__c, Role__c, IsDirect
            FROM AccountContactRelation
            WHERE AccountId IN :accountList
        ]) {
            //combine accountID + contact_person_ID to avoid map in map
            String accountContactId = accrelation.AccountId + accrelation.Contact_Person_ID__c;
            accountRelationsByAccountContactId.put(accountContactId, accrelation);
        }

        return accountRelationsByAccountContactId;
    }

    /**
     * Get all existing AccountContactRelations for incoming Accounts
     *
     * @param accountList incoming Accounts
     *
     * @return existing AccountContactRelations mapped and grouped by AccountId
     */
    public Map<String, List<AccountContactRelation>> getExistingAccountRelations(List<Account> accountList) {
        Map<String, List<AccountContactRelation>> accountRelationsByAccountId = new Map<String, List<AccountContactRelation>>();

        for (Account acc : [
            SELECT
                Id,
                Core_Customer_Number__c,
                (
                    SELECT Id, AccountId, Contact_Person_ID__c, External_ID__c, Role__c, IsDirect
                    FROM AccountContactRelations
                )
            FROM Account
            WHERE Id IN :accountList
        ]) {
            List<AccountContactRelation> acrList = new List<AccountContactRelation>();
            for(AccountContactRelation acr : acc.AccountContactRelations) {
                acrList.add(acr);
            }
            accountRelationsByAccountId.put(acc.Id, acrList);
        }

        return accountRelationsByAccountId;
    }

    /**
     * Get all existing AccountContactRelations for incoming Contacts mapped by their person Id
     *
     * @param contactList incoming Contacts
     *
     * @return existing AccountContactRelations mapped and grouped by PersonID__c
     */
    public Map<String, List<AccountContactRelation>> getExistingAccountContactRelationsbyContact(Set<String> contactPersonIds) {
        Map<String, List<AccountContactRelation>> accountRelationsByContactId = new Map<String, List<AccountContactRelation>>();

        for (Contact con : [
            SELECT
                Id,
                PersonID__c,
                (
                    SELECT Id, AccountId, ContactId, Contact_Person_ID__c, External_ID__c, Role__c, IsDirect
                    FROM AccountContactRelations
                )
            FROM Contact
            WHERE PersonID__c IN :contactPersonIds
        ]) {
            accountRelationsByContactId.put(con.PersonID__c, con.AccountContactRelations);
        }
        
        return accountRelationsByContactId;
    }

    /**
     * Get all PersonIDs for contacts of incoming accounts
     *
     * @param jsonArray incoming json response
     *
     * @return Set of PersonIDs from contacts
     */
    private Set<String> filterAllContainedPersonIdsFromJson(List<Object> jsonArray) {
        Set<String> personIds = new Set<String>();
        for (Object jsonItem : jsonArray) {
            Map<String, Object> jsonAcc = (Map<String, Object>) jsonItem;
            // get Contacts Array
            List<Object> contactsArray = (List<Object>) jsonAcc.get('Contacts');
            for (Object contactItem : contactsArray) {
                Map<String, Object> jsonContact = (Map<String, Object>) contactItem;
                String personId = (String) jsonContact.get('PersonID__c');
                personIds.add(personId);
            }
        }
        return personIds;
    }

    /**
     * Get all existing contacts matching contacts of incoming accounts
     *
     * @param jsonArray incoming json response
     *
     * @return Set of PersonIDs from existing contacts
     */
    public Set<String> filterExistingPersonIdsMatchByIncomingPersonIds(List<Object> jsonArray) {
        Set<String> externalPersonIds = filterAllContainedPersonIdsFromJson(jsonArray);
        List<Contact> existingContacts = [SELECT PersonID__c FROM Contact WHERE PersonID__c IN :externalPersonIds];
        Set<String> existingPersonIds = UTLCommons.filterStringFieldValues(existingContacts, Contact.PersonID__c);
        return existingPersonIds;
    }
}