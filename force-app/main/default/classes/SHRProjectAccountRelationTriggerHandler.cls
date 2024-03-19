/**
 * Handler class detekt changes and routes to the business logic handlers
 * and executes dml operations.
 *
 * @author  isabella.moos@accenture.com
 *
 * @version 2023-10-09  isabella.moos@accenture.com     creation
 */
public with sharing class SHRProjectAccountRelationTriggerHandler extends UTLTriggerHandler  {
    public String CLASSNAME = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));

    private DUPProjectAccountRelationHandler dupPARHandler = new DUPProjectAccountRelationHandler();

    private List<Project_Account_Relation__c> newPAR;
    private Map<Id, Project_Account_Relation__c> oldPARsByIds;
    private Map<Id, Project_Account_Relation__c> newPARsByIds;

    Map<Id, Project_Account_Relation__c> oldPARMap = new Map<Id, Project_Account_Relation__c>();
    Map<Id, Project_Account_Relation__c> newPARMap = new Map<Id, Project_Account_Relation__c>();

    public SHRProjectAccountRelationTriggerHandler() {
        this.oldPARsByIds = (Map<Id, Project_Account_Relation__c>) Trigger.oldMap;
        this.newPARsByIds = (Map<Id, Project_Account_Relation__c>) Trigger.newMap;
    }

    /**
     * Collecting inserted records and handle dml operations.
     *
     * @see UTLTriggerHandler.afterInsert
     */
    public override void afterInsert() {
        // Handle record update
        for (Id parId : this.newPARsByIds.keySet()) {
            Project_Account_Relation__c newPAR = this.newPARsByIds.get(parId);

            this.newPARMap.put(newPAR.Id, newPAR);
        }
        // handle if related Account Name change occured
        if (!newPARMap.isEmpty()) {
            this.dupPARHandler
                .addNewPARs(this.newPARsByIds)
                .executeJob(DUPProjectAccountRelationHandler.JobContext.ON_INSERT);
        }
    }

    /**
     * Collecting changed records and handle dml operations.
     *
     * @see UTLTriggerHandler.afterUpdate
     */
    public override void afterUpdate() {
        // Handle record update
        for (Id parId : this.newPARsByIds.keySet()) {
            Project_Account_Relation__c oldPAR = this.oldPARsByIds.get(parId);
            Project_Account_Relation__c newPAR = this.newPARsByIds.get(parId);

            if (oldPAR.Account__c != newPAR.Account__c || 
            oldPAR.Account_Role__c != newPAR.Account_Role__c ||
            oldPAR.Project__c != newPAR.Project__c) {
                oldPARMap.put(oldPAR.Id, oldPAR);
                newPARMap.put(newPAR.Id, newPAR);
            }
        }
        // handle if related Account Name change occured
        if (! newPARMap.isEmpty() && 
        ! oldPARMap.isEmpty()) {
            this.dupPARHandler
                .addOldPARs(this.oldPARsByIds)
                .addNewPARs(this.newPARsByIds)
                .executeJob(DUPProjectAccountRelationHandler.JobContext.ON_UPDATE);
        }
    }

    /**
     * Collecting deleted records and handle dml operations.
     *
     * @see UTLTriggerHandler.afterDelete
     */
    public override void afterDelete() {
        // Handle record deletion
        for (Id parId : this.oldPARsByIds.keySet()) {
            Project_Account_Relation__c oldPAR = this.oldPARsByIds.get(parId);

            this.oldPARMap.put(oldPAR.Id, oldPAR);
        }
        // handle if related Account Name change occured
        if (! oldPARMap.isEmpty()) {
            this.dupPARHandler
                .addOldPARs(this.oldPARsByIds)
                .executeJob(DUPProjectAccountRelationHandler.JobContext.ON_DELETE);
        }
    }

    /**
     * Collecting deleted records and handle dml operations.
     *
     * @see UTLTriggerHandler.afterUndelete
     */
    public override void afterUndelete() {
        // Handle record deletion
        for (Id parId : this.newPARsByIds.keySet()) {
            Project_Account_Relation__c newPAR = this.newPARsByIds.get(parId);

            this.newPARMap.put(newPAR.Id, newPAR);
        }
        // handle if related Account Name change occured
        if (! newPARMap.isEmpty()) {
            this.dupPARHandler
                .addNewPARs(this.newPARsByIds)
                .executeJob(DUPProjectAccountRelationHandler.JobContext.ON_UNDELETE);
        }
    }
}