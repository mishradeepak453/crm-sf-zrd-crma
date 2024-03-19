/**
 * Handler class detect changes and routes to the business logic handlers
 * and executes dml operations.
 *
 * @author  daniel.gette@zeppelin.com
 *
 * @version 20.10.23    isabella.moos@accenture.com     creation as part of SF-1205
 */
public with sharing class SHRAccountLeadTriggerHandler extends UTLTriggerHandler {
    public String CLASSNAME = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));

    private List<Account_Lead__c> newAccountLeads;
    private Map<Id, Account_Lead__c> oldAccountLeadsByIds;
    private Map<Id, Account_Lead__c> newAccountLeadsByIds;

    // Handle changes on Account_Lead__c Name for duplicate check
    private DUPAccountLeadHandler duplicateCheckHandler = new DUPAccountLeadHandler();
    private Map<Id, Account_Lead__c> oldMapNameChanged = new Map<Id, Account_Lead__c>();
    private Map<Id, Account_Lead__c> newMapNameChanged = new Map<Id, Account_Lead__c>();

    public SHRAccountLeadTriggerHandler() {
        this.newAccountLeads = (List<Account_Lead__c>) Trigger.new;
        this.oldAccountLeadsByIds = (Map<Id, Account_Lead__c>) Trigger.oldMap;
        this.newAccountLeadsByIds = (Map<Id, Account_Lead__c>) Trigger.newMap;
    }

    /**
     * Collecting changed records and handle dml operations.
     *
     * @see UTLTriggerHandler.afterUpdate
     */
    public override void afterUpdate() {
        // route changes
        for (Id accountLeadId : this.newAccountLeadsByIds.keySet()) {
            Account_Lead__c oldAccountLead = this.oldAccountLeadsByIds.get(accountLeadId);
            Account_Lead__c newAccountLead = this.newAccountLeadsByIds.get(accountLeadId);

            if(oldAccountLead.Name != newAccountLead.Name) {
                this.oldMapNameChanged.put(oldAccountLead.Id, oldAccountLead);
                this.newMapNameChanged.put(newAccountLead.Id, newAccountLead);
            }
        }

        //handle if name changes occured
        if (!oldMapNameChanged.isEmpty() &&
        !newMapNameChanged.isEmpty()) {
            this.duplicateCheckHandler
                .addOldAccounts(this.oldAccountLeadsByIds)
                .addNewAccounts(this.newAccountLeadsByIds)
                .executeJob(DUPAccountLeadHandler.JobContext.ON_UPDATE);
        }
    }
}