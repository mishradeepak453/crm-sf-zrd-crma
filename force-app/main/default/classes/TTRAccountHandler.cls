/**
 * SF-848: Account-Vertriebsgebiete zuweisen über Fieldupdate aus Grace
 *
 * @author  daniel.gette@zeppelin.com
 *
 * @version 05.01.22 daniel.gette@zeppelin.com creation
 * @version 12.01.23 miriam.ida.tyroller@accenture.com edit territory handling
 */
public without sharing class TTRAccountHandler {
    private String CLASSNAME = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));

    private Map<String, Territory2> territoriesBySalesUnitIds;
    private Map<Id, Account> oldAccountsByIds;
    private Map<Id, Account> newAccountsByIds;

    private Map<Id, TTRAccountHandlerException> territoryHelperExceptions = new Map<Id, TTRAccountHandlerException>();

    public TTRAccountHandler(){
        this.territoriesBySalesUnitIds = initTerritoryMap();
    }

    /**
     * Chain-Methode to build the Handler
     *
     * @param TTRsBySuIds Territory-Map by SalesUnitIds are mandatory
     *
     * @return TTRAccountHandler
     */
    public TTRAccountHandler addTerritoriesBySuIds(Map<String, Territory2> TTRsBySuIds) {
        this.territoriesBySalesUnitIds = TTRsBySuIds;
        return this;
    }
    /**
     * Chain-Methode to build the Handler
     *
     * @param newAccountsByIds New Accounts-Maps are mandatory
     *
     * @return TTRAccountHandler
     */
    public TTRAccountHandler addNewAccounts(Map<Id, Account> newAccountsByIds) {
        this.newAccountsByIds = newAccountsByIds;
        return this;
    }

    /**
     * Chain-Methode to build the Handler
     *
     * @param oldAccountsByIds New Accounts-Maps are mandatory
     *
     * @return TTRAccountHandler
     */
    public TTRAccountHandler addOldAccounts(Map<Id, Account> oldAccountsByIds) {
        this.oldAccountsByIds = oldAccountsByIds;
        return this;
    }

    /**
     * To choose async execution-context
     */
    public enum JobContext {
        ON_INSERT,
        ON_UPDATE
    }

    /**
     * Async execution methode
     *
     * @param context JobContext is mandatory to chose execution-context
     */
    public void executeJob(JobContext context) {
        TTRAccountHandlerJob ttrAccQueueable = new TTRAccountHandlerJob(this, context);

        if (
            context == JobContext.ON_UPDATE &&
            (this.territoriesBySalesUnitIds == null ||
            this.oldAccountsByIds == null ||
            this.newAccountsByIds == null ||
            this.newAccountsByIds.isEmpty())
        ) {
            throw new TTRAccountHandlerException('Accounts or Territories not properly initiated.');
        } else if (
            context == JobContext.ON_INSERT &&
            (this.territoriesBySalesUnitIds == null ||
            this.newAccountsByIds == null ||
            this.newAccountsByIds.isEmpty())
        ) {
            throw new TTRAccountHandlerException('Accounts or Territories not properly initiated.');
        } else {
            System.enqueueJob(ttrAccQueueable);
        }
    }

    /**
     * To execute the outer class in an async context.
     */
    private class TTRAccountHandlerJob implements Queueable, Database.AllowsCallouts {
        private String CLASSNAME = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));

        private JobContext context;

        private TTRAccountHandler tTRAccountHandler;

        private TTRAccountHandlerJob(TTRAccountHandler tTRAccountHandler, JobContext context) {
            this.tTRAccountHandler = tTRAccountHandler;
            this.context = context;
        }

        public void execute(QueueableContext qc) {
            try {
                switch on Context {
                    when ON_INSERT {
                        tTRAccountHandler.handlePostalCodeChangesOnInsertAsync();
                    }
                    when ON_UPDATE {
                        tTRAccountHandler.handlePostalCodeChangesOnUpdateAsync();
                    }
                    when else {
                        throw new TTRAccountHandlerException('Unknown JobContext');
                    }
                }
            } catch (Exception e) {
                UTLErrorLog.insertErrorLogs(
                    new List<Core_Error_Log__c>{
                        UTLErrorLog.createErrorLogRecord(
                            this.CLASSNAME,
                            e,
                            'Queueable-Execution-Error on Territory Handling',
                            qc.getJobId()
                        )
                    },
                    this.CLASSNAME
                );
            }
        }
    }

    /**
     * Async On-Insert handling
     */
    private void handlePostalCodeChangesOnInsertAsync() {
        handlePostalCodeChangesOnInsert(this.newAccountsByIds);
        //handle TerritoryHelperExceptions
        if (!this.territoryHelperExceptions.isEmpty())
            UTLErrorLog.insertErrorLogs(createsExcetionLogs(this.territoryHelperExceptions), CLASSNAME);
    }

    /**
     * Async On-Update handling
     */
    private void handlePostalCodeChangesOnUpdateAsync() {
        handlePostalCodeChangesOnUpdate(this.newAccountsByIds);
        //handle TerritoryHelperExceptions
        if (!this.territoryHelperExceptions.isEmpty())
            UTLErrorLog.insertErrorLogs(createsExcetionLogs(this.territoryHelperExceptions), CLASSNAME);
    }

    /**
     * Creates Exceptions mapped by Account Ids
     *
     * @param e Single Exception to replicate by Account-Id
     * @param accountsByIds Account
     */
    private void createExceptionsMappedByPerAccount(Exception e, Map<Id, Account> accountsByIds) {
        for (Id accountId : accountsByIds.keySet()) {
            this.territoryHelperExceptions.put(accountId, new TTRAccountHandlerException(e.getMessage()));
        }
    }

    /**
     * On-Update handling
     *
     * @param accountsByIds Accounts from Trigger.newMap
     */
    private void handlePostalCodeChangesOnInsert(Map<Id, Account> accountsByIds) {
        // get rental Salesunits

        Map<Id, List<SHRGraceAPI.SalesUnit>> newExternalTerritories = new Map<Id, List<SHRGraceAPI.SalesUnit>>();
        try {
            newExternalTerritories = calloutRentalSalesUnitsMappedByIds(accountsByIds);
        } catch (Exception e) {
            createExceptionsMappedByPerAccount(e, accountsByIds);
        }

        // add bulkified records
        if (!newExternalTerritories.isEmpty()) {
            insert filterObjectTerritory2AssociationToCreate(newExternalTerritories);
        }
    }

    /**
     * Methode handles changed Territory_IDs__c and creates and removes ObjectTerritory2Association on demand
     *
     * @param newAccountsByIds Accounts from Trigger.newMap
     */
    private void handlePostalCodeChangesOnUpdate(Map<Id, Account> newAccountsByIds) {
        // get rental Salesunits
        Map<Id, List<SHRGraceAPI.SalesUnit>> newExtTerByBusinessAreas = new Map<Id, List<SHRGraceAPI.SalesUnit>>();
        try {
            // api call
            newExtTerByBusinessAreas = calloutRentalSalesUnitsMappedByIds(newAccountsByIds);
        } catch (Exception e) {
            createExceptionsMappedByPerAccount(e, newAccountsByIds);
            return;
        }

        // collector Lists for DML operations
        Map<Id, List<SHRGraceAPI.SalesUnit>> addedExternalTerritories = new Map<Id, List<SHRGraceAPI.SalesUnit>>();
        for (Id accountId : newAccountsByIds.keySet()) {
            try {
                List<SHRGraceAPI.SalesUnit> newExternalTTRList = newExtTerByBusinessAreas.get(accountId);
                List<SHRGraceAPI.SalesUnit> newSalesUnitList = new List<SHRGraceAPI.SalesUnit>();

                if (newExternalTTRList == null) {
                    // case on empty responses
                    continue;
                } else {
                    for (SHRGraceAPI.SalesUnit salesUnit : newExternalTTRList) {
                        newSalesUnitList.add(salesUnit);
                    }
                    addedExternalTerritories.put(accountId, newSalesUnitList);
                }
            } catch (Exception e) {
                this.territoryHelperExceptions.put(
                    accountId,
                    new TTRAccountHandlerException('Processing error: ' + e.getMessage())
                );
            }
        }

        // remove bulkify records
        if (!newAccountsByIds.isEmpty()) {
            // find ObjectTerritory2Association related to the accounts
            List<ObjectTerritory2Association> objTTRAssociations = filterObjectTerritory2AssociationToRemove(
                newAccountsByIds
            );
            if (!objTTRAssociations.isEmpty()) {
                delete objTTRAssociations;
            }
        }

        // add bulkified records
        if (!addedExternalTerritories.isEmpty()) {
            List<ObjectTerritory2Association> objTTRAssociations = filterObjectTerritory2AssociationToCreate(
                addedExternalTerritories
            );
            Database.DMLOptions dmlOptions = new Database.DMLOptions();
                dmlOptions.optAllOrNone = false;

            Database.insert(objTTRAssociations, dmlOptions);
        }
    }

    /**
     * Callout rental SalesUnits MappedByIds
     *
     * @param accountsByIds Accounts mapped by Account-Id's
     *
     * @return SalesUnitList mapped by AccountId's
     */
    private Map<Id, List<SHRGraceAPI.SalesUnit>> calloutRentalSalesUnitsMappedByIds(Map<Id, Account> accountsByIds) {
        Map<Id, List<SHRGraceAPI.SalesUnit>> salesUnitListbyAccountId = new Map<Id, List<SHRGraceAPI.SalesUnit>>();
        List<String> billingPostalCodes = new List<String>();

        //get postalcodes for all accounts
        for (Account acc : accountsByIds.values()) {
            billingPostalCodes.add(acc.BillingPostalCode);
        }

        Map<String, List<SHRGraceAPI.SalesUnit>> salesUnitListbyPLZ = SHRGraceAPI.getSalesUnitsByPostalCodeList(
            billingPostalCodes
        );

        //map accounts by their postalcode with list of SalesUnits
        for (Account acc : accountsByIds.values()) {
            List<SHRGraceAPI.SalesUnit> salesUnitList = salesUnitListbyPLZ.get(acc.BillingPostalCode);

            if (salesUnitList != null) {
                salesUnitListbyAccountId.put(acc.Id, salesUnitList);
            }
        }

        return salesUnitListbyAccountId;
    }

    /**
     * Creates ObjectTerritory2Associations with the Project Territory-Hierarchy.
     *
     * @param externalTerritoriesByAccountids List of ExternalTerritories mapped by Account Id's.
     *
     * @return List of ObjectTerritory2Association to insert
     */
    public List<ObjectTerritory2Association> filterObjectTerritory2AssociationToCreate(
        Map<Id, List<SHRGraceAPI.SalesUnit>> externalTerritoriesByAccountids
    ) {
        List<ObjectTerritory2Association> objectTerritory2Associations = new List<ObjectTerritory2Association>();
        this.territoryHelperExceptions = new Map<Id, TTRAccountHandlerException>();

        //for each account, create ObjectTerritory2Associations for each salesUnit
        for (Id accountId : externalTerritoriesByAccountids.keySet()) {
            List<Territory2> territoryList = new List<Territory2>();


                List<SHRGraceAPI.SalesUnit> salesUnitList = externalTerritoriesByAccountids.get(accountId);

                for (SHRGraceAPI.SalesUnit salesUnit : salesUnitList) {
                    try {
                        Territory2 territory = this.territoriesBySalesUnitIds.get(salesUnit.salesunitid);
                        if (territory == null){
                            throw new TTRAccountHandlerException(
                                'External Territory-Ids not present in the Territory Model. ' +
                                'Territory-Ids:(' +
                                salesUnit.salesunitid +
                                ')'
                            );
                        }
                        else {
                            territoryList.add(territory);
                        }
                    }
                    catch (TTRAccountHandlerException e) {
                        territoryHelperExceptions.put(accountId, e);
                    }
                }

                for (territory2 terr : territoryList) {
                    try{
                        if(terr != null && accountId != null){
                            objectTerritory2Associations.add(createTtrAssociation(terr.Id, accountId));
                        }
                    }
                    catch (TTRAccountHandlerException e) {
                        territoryHelperExceptions.put(accountId, e);
                    }
                }
        }

        return objectTerritory2Associations;
    }

    /**
     * Creates ObjectTerritory2Associations with the Project Territory-Hierarchy.
     *
     * @param externalTerritoriesByCuNumbers List of ExternalTerritories mapped by Account Customer Numbers.
     *
     * @return List of ObjectTerritory2Association to insert
     */
    public List<ObjectTerritory2Association> filterObjectTerritory2AssociationToCreate(
        Map<String, List<SHRGraceAPI.SalesUnit>> externalTerritoriesByCuNumbers
    ) {

        List<Account> accList = [SELECT Id, Name, Core_Customer_Number__c FROM Account WHERE Core_Customer_Number__c IN :externalTerritoriesByCuNumbers.keySet()]; 
        Map<String,SObject> existingAccountsMappedByCustomerNumber = UTLCommons.mapByStringField(
                accList,
                Account.Core_Customer_Number__c
            );

        List<ObjectTerritory2Association> objectTerritory2Associations = new List<ObjectTerritory2Association>();
        this.territoryHelperExceptions = new Map<Id, TTRAccountHandlerException>();

        //for each account, create ObjectTerritory2Associations for each salesUnit
        for (String accountCuNumber : externalTerritoriesByCuNumbers.keySet()) {
            List<Territory2> territoryList = new List<Territory2>();
            List<SHRGraceAPI.SalesUnit> salesUnitList = externalTerritoriesByCuNumbers.get(accountCuNumber);
            Account acc = (Account) existingAccountsMappedByCustomerNumber.get(accountCuNumber);
            //check if account was actually successfully created 
            if (acc != null){
                for (SHRGraceAPI.SalesUnit salesUnit : salesUnitList) {
                    try {
                        Territory2 territory = this.territoriesBySalesUnitIds.get(salesUnit.salesunitid);
                        if (territory == null){
                            throw new TTRAccountHandlerException(
                                'External Territory-Ids not present in the Territory Model. ' +
                                'Territory-Ids:(' +
                                salesUnit.salesunitid +
                                ')'
                            );
                        }
                        else {
                            territoryList.add(territory);
                        }
                    }
                    catch (TTRAccountHandlerException e) {
                        territoryHelperExceptions.put(acc.Id, e);
                    }
                }

                for (territory2 terr : territoryList) {
                    try{
                        if(terr != null && acc != null){
                            objectTerritory2Associations.add(createTtrAssociation(terr.Id, acc.Id));
                        } 
                    }
                    catch (TTRAccountHandlerException e) {
                        territoryHelperExceptions.put(acc.Id, e);
                    }
                }
            }
        }
        return objectTerritory2Associations;
    }

    /**
     * Helper Methode creating ObjectTerritory2Association with AssociationCause 'Territory2Manual'.
     *
     * @param territoryId Territory-Id to association with
     * @param accountId Account-Id to association with
     *
     * @return ObjectTerritory2Association with all mandatory fields
     */
    private ObjectTerritory2Association createTtrAssociation(Id territoryId, Id accountId) {
        ObjectTerritory2Association objectTerritory2Association = new ObjectTerritory2Association();
        objectTerritory2Association.Territory2Id = territoryId;
        objectTerritory2Association.ObjectId = accountId;
        objectTerritory2Association.AssociationCause = 'Territory2Manual';
        return objectTerritory2Association;
    }

    /**
     * Find all ObjectTerritory2Associations that exist for an account to remove
     *
     * @param externalTerritoriesByAccountIds
     *
     * @return ObjectTerritory2Associations to remove
     */
    public List<ObjectTerritory2Association> filterObjectTerritory2AssociationToRemove(
        Map<Id, Account> newAccountsByIds
    ) {
        // Fetch all Territories associated with accounts
        List<ObjectTerritory2Association> territory2AssociationBaseAmount = new List<ObjectTerritory2Association>(
            [
                SELECT Id, Territory2Id, ObjectId, Territory2.Core_External_ID__c
                FROM ObjectTerritory2Association
                WHERE ObjectId IN :newAccountsByIds.keySet()
            ]
        );

        return territory2AssociationBaseAmount;
    }

    /**
     * Initialize Territory-Map of all Territories on the lowest level, for future processing.
     * 
     * @return Territories mapped by SalesunitId aka Territory.Core_External_Id__c
     */
    public Map<String, Territory2> initTerritoryMap() {
        Map<String, Territory2> territoriesBySalesUnitIds = new Map<String, Territory2>();
        Map<Id, Territory2> territories = new Map<Id, Territory2>(
            [
                SELECT
                    Id,
                    Name,
                    Core_External_ID__c,
                    ParentTerritory2.Id,
                    ParentTerritory2.Core_External_ID__c,
                    ParentTerritory2.ParentTerritory2.Id,
                    ParentTerritory2.ParentTerritory2.Core_External_ID__c
                FROM Territory2
                WHERE Core_External_ID__c LIKE 'M%'
            ]
        );

        // Map SalesUnits as Key
        for (Territory2 territory : territories.values()) {
            territoriesBySalesUnitIds.put(territory.Core_External_ID__c, territory);
        }
        return territoriesBySalesUnitIds;
    }


    /**
     * Maps TerritoryHelperException and Account-Id's to a List of Core_Error_Log__c.
     *
     * @param territoryHelperExceptionsByAccountIds created Core_Error_Log__c list
     *
     * @return List of Core_Error_Log__c
     */
    private List<Core_Error_Log__c> createsExcetionLogs(
        Map<Id, TTRAccountHandlerException> territoryHelperExceptionsByAccountIds
    ) {
        List<Core_Error_Log__c> coreErrorLogs = new List<Core_Error_Log__c>();
        for (Id accountId : territoryHelperExceptionsByAccountIds.keySet()) {
            TTRAccountHandler.TTRAccountHandlerException ttrAccountHandlerException = territoryHelperExceptionsByAccountIds.get(
                accountId
            );
            System.debug('Exception occured:');
            System.debug('Message:' + ttrAccountHandlerException.getMessage());
            System.debug('Stack:' + ttrAccountHandlerException.getStackTraceString());
            System.debug('Line:' + ttrAccountHandlerException.getLineNumber());

            Core_Error_Log__c coreErrorLog = UTLErrorLog.createErrorLogRecord(
                CLASSNAME,
                ttrAccountHandlerException,
                'Error on Territory Handling',
                accountId
            );
            coreErrorLogs.add(coreErrorLog);
        }
        return coreErrorLogs;
    }

    public class TTRAccountHandlerException extends Exception {
    }
}