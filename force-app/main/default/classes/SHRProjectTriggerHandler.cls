/**
 * Handler class detekt changes and routes to the business logic handlers
 * and executes dml operations.
 *
 * @author  isabella.moos@accenture.com
 *
 * @version 2023-10-18  isabella.moos@accenture.com     creation
 */
public with sharing class SHRProjectTriggerHandler extends UTLTriggerHandler  {
    public String CLASSNAME = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));

    private DUPProjectHandler dupProjectHandler = new DUPProjectHandler();

    private List<Project__c> newProject;
    private Map<Id, Project__c> oldProjectsByIds;
    private Map<Id, Project__c> newProjectsByIds;

    private Map<Id, Project__c> newProjectsMap = new Map<Id, Project__c>();

    public SHRProjectTriggerHandler() {
        this.newProject = (List<Project__c>) Trigger.new;
        this.oldProjectsByIds = (Map<Id, Project__c>) Trigger.oldMap;
        this.newProjectsByIds = (Map<Id, Project__c>) Trigger.newMap;
    }

    /**
     * Collecting changed records and handle dml operations.
     *
     * @see UTLTriggerHandler.beforeUpdate
     */
    public override void beforeUpdate() {
        // Handle address update
        for (Id projectId : this.newProjectsByIds.keySet()) {
            Project__c oldProject = this.oldProjectsByIds.get(projectId);
            Project__c newProject = this.newProjectsByIds.get(projectId);

            if (oldProject.Project_Address__Street__s != newProject.Project_Address__Street__s) {
                newProjectsMap.put(newProject.Id, newProject);
            }
        }
        // handle if related Account Name change occured
        if (! newProjectsMap.isEmpty()) {
            this.dupProjectHandler
                .addOldProjects(oldProjectsByIds)
                .addNewProjects(newProjectsByIds)
                .handleProjectAddressChanges(this.newProjectsMap);
        }
    }
}