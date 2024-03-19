/**
 * Handler class detekt changes and routes to the business logic handlers
 * and executes dml operations.
 *
 * @author  daniel.gette@zeppelin.com
 *
 * @version 30.12.21    daniel.gette@zeppelin.com       creation
 * @version 19.10.23    isabella.moos@accenture.com     add changes for duplicate check as part of SF-1205
 */
public with sharing class SHRAccountTriggerHandler extends UTLTriggerHandler {
    public String CLASSNAME = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));

    private List<Account> newAccounts;
    private Map<Id, Account> oldAccountsByIds;
    private Map<Id, Account> newAccountsByIds;

    // Business-Process Territory-Mangament
    private TTRAccountHandler territoryHandler = new TTRAccountHandler();
    private Map<Id, Account> oldMapPostalCodeChanged = new Map<Id, Account>();
    private Map<Id, Account> newMapPostalCodeChanged = new Map<Id, Account>();

    // react to changes on postl code
    private List<Account> accPostalCodeChanged = new List<Account>();

    // Handle changes on Account Name for duplicate check
    private DUPAccountHandler duplicateCheckHandler = new DUPAccountHandler();
    private Map<Id, Account> oldMapNameChanged = new Map<Id, Account>();
    private Map<Id, Account> newMapNameChanged = new Map<Id, Account>();

    public SHRAccountTriggerHandler() {
        this.newAccounts = (List<Account>) Trigger.new;
        this.oldAccountsByIds = (Map<Id, Account>) Trigger.oldMap;
        this.newAccountsByIds = (Map<Id, Account>) Trigger.newMap;
    }

    /**
     * Collecting changed records and handle dml operations.
     *
     * @see UTLTriggerHandler.afterInsert
     */
    public override void afterInsert() {
        // Handle Territory_IDs__c changes
        Map<Id, Account> newAccsWithChangedTerritoryIdsField = new Map<Id, Account>();
        for (Id accountId : this.newAccountsByIds.keySet()) {
            Account account = this.newAccountsByIds.get(accountId);

            if (!String.isEmpty(account.BillingPostalCode)) {
                accPostalCodeChanged.add(account);
            }
        }

        // handle if PostalCode changes occured
        if (!accPostalCodeChanged.isEmpty()) {
            this.territoryHandler
                .addNewAccounts(this.newAccountsByIds)
                .executeJob(TTRAccountHandler.JobContext.ON_INSERT);
        }
    }

    /**
     * Collecting changed records and handle dml operations.
     *
     * @see UTLTriggerHandler.afterInsert
     */
    public override void afterUpdate() {
        // route changes
        for (Id accountId : this.newAccountsByIds.keySet()) {
            Account oldAccount = this.oldAccountsByIds.get(accountId);
            Account newAccount = this.newAccountsByIds.get(accountId);

            if (oldAccount.BillingPostalCode != newAccount.BillingPostalCode) {
                this.oldMapPostalCodeChanged.put(oldAccount.Id, oldAccount);
                this.newMapPostalCodeChanged.put(newAccount.Id, newAccount);
            }

            if(oldAccount.Name != newAccount.Name) {
                this.oldMapNameChanged.put(oldAccount.Id, oldAccount);
                this.newMapNameChanged.put(newAccount.Id, newAccount);
            }
        }
        // handle if PostalCode changes occured
        if (!newMapPostalCodeChanged.isEmpty()) {
            this.territoryHandler
                .addOldAccounts(this.oldAccountsByIds)
                .addNewAccounts(this.newAccountsByIds)
                .executeJob(TTRAccountHandler.JobContext.ON_UPDATE);
        }

        //handle if name changes occured
        if (!oldMapNameChanged.isEmpty() &&
        !newMapNameChanged.isEmpty()) {
            this.duplicateCheckHandler
                .addOldAccounts(this.oldAccountsByIds)
                .addNewAccounts(this.newAccountsByIds)
                .executeJob(DUPAccountHandler.JobContext.ON_UPDATE);
        }
    }
}