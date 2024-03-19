/**
 * Handler class detekt changes and routes to the business logic handlers
 * and executes dml operations.
 *
 * @author  isabella.moos@accenture.com
 *
 * @version 2023-10-20  isabella.moos@accenture.com     creation
 */
public with sharing class SHRPALRTriggerHandler extends UTLTriggerHandler  {
    public String CLASSNAME = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));

    private DUPPALRHandler palrHandler = new DUPPALRHandler();

    private List<Project_Account_Lead_Relation__c> newPALR;
    private Map<Id, Project_Account_Lead_Relation__c> oldPALRsByIds;
    private Map<Id, Project_Account_Lead_Relation__c> newPALRsByIds;

    Map<Id, Project_Account_Lead_Relation__c> oldPALRMap = new Map<Id, Project_Account_Lead_Relation__c>();
    Map<Id, Project_Account_Lead_Relation__c> newPALRMap = new Map<Id, Project_Account_Lead_Relation__c>();

    public SHRPALRTriggerHandler() {
        this.oldPALRsByIds = (Map<Id, Project_Account_Lead_Relation__c>) Trigger.oldMap;
        this.newPALRsByIds = (Map<Id, Project_Account_Lead_Relation__c>) Trigger.newMap;
    }

    /**
     * Collecting inserted records and handle dml operations.
     *
     * @see UTLTriggerHandler.afterInsert
     */
    public override void afterInsert() {
        // Handle record update
        for (Id palrId : this.newPALRsByIds.keySet()) {
            Project_Account_Lead_Relation__c newPALR = this.newPALRsByIds.get(palrId);

            this.newPALRMap.put(newPALR.Id, newPALR);
        }
        // handle if related Account Name change occured
        if (!newPALRMap.isEmpty()) {
            this.palrHandler
                .addNewPALRs(this.newPALRsByIds)
                .executeJob(DUPPALRHandler.JobContext.ON_INSERT);
        }
    }

    /**
     * Collecting changed records and handle dml operations.
     *
     * @see UTLTriggerHandler.afterUpdate
     */
    public override void afterUpdate() {
        // Handle record update
        for (Id palrId : this.newPALRsByIds.keySet()) {
            Project_Account_Lead_Relation__c oldPALR = this.oldPALRsByIds.get(palrId);
            Project_Account_Lead_Relation__c newPALR = this.newPALRsByIds.get(palrId);

            if (oldPALR.Account_Lead__c != newPALR.Account_Lead__c || 
            oldPALR.Account_Role__c != newPALR.Account_Role__c) {
                oldPALRMap.put(oldPALR.Id, oldPALR);
                newPALRMap.put(newPALR.Id, newPALR);
            }
        }
        // handle if related Account Name change occured
        if (! newPALRMap.isEmpty() && 
        ! oldPALRMap.isEmpty()) {
            this.palrHandler
                .addOldPALRs(this.oldPALRsByIds)
                .addNewPALRs(this.newPALRsByIds)
                .executeJob(DUPPALRHandler.JobContext.ON_UPDATE);
        }
    }

    /**
     * Collecting deleted records and handle dml operations.
     *
     * @see UTLTriggerHandler.afterDelete
     */
    public override void afterDelete() {
        // Handle record deletion
        for (Id palrId : this.oldPALRsByIds.keySet()) {
            Project_Account_Lead_Relation__c oldPALR = this.oldPALRsByIds.get(palrId);

            this.oldPALRMap.put(oldPALR.Id, oldPALR);
        }
        // handle if related Account Name change occured
        if (! oldPALRMap.isEmpty()) {
            this.palrHandler
                .addOldPALRs(this.oldPALRsByIds)
                .executeJob(DUPPALRHandler.JobContext.ON_DELETE);
        }
    }

    /**
     * Collecting deleted records and handle dml operations.
     *
     * @see UTLTriggerHandler.afterUndelete
     */
    public override void afterUndelete() {
        // Handle record deletion
        for (Id palrId : this.newPALRsByIds.keySet()) {
            Project_Account_Lead_Relation__c newPALR = this.newPALRsByIds.get(palrId);

            this.newPALRMap.put(newPALR.Id, newPALR);
        }
        // handle if related Account Name change occured
        if (! newPALRMap.isEmpty()) {
            this.palrHandler
                .addNewPALRs(this.newPALRsByIds)
                .executeJob(DUPPALRHandler.JobContext.ON_UNDELETE);
        }
    }
}