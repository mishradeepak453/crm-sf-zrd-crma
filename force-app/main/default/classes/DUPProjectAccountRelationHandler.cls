/**
 * SF-1205: Update helper fields for involved accounts on related Project__c records
 *
 * @author  isabella.moos@accenture.com
 *
 * @version 2023-10-09      isabella.moos@accenture.com     creation
 */
public without sharing class DUPProjectAccountRelationHandler {
    @TestVisible
    private String CLASSNAME = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));
    private static String PROJECT_ACCOUNT_RELATION_SOBJECT_API_NAME = 'Project_Account_Relation__c';
    private static String ACCOUNT_ROLE_FIELD_API_NAME = 'Account_Role__c';

    private Map<Id, Project_Account_Relation__c> oldPARsByIds;
    private Map<Id, Project_Account_Relation__c> newPARsByIds;

    private Map<Id, DUPProjectAccountRelationHandlerException> DUPPARHandlerExceptions = new Map<Id, DUPProjectAccountRelationHandlerException>();

    /**
     * Chain-Method to build the Handler
     *
     * @param oldPARsByIds Old ProjectAccountRelation-Maps is mandatory
     *
     * @return DUPProjectAccountRelationHandler
     */
    public DUPProjectAccountRelationHandler addOldPARs(Map<Id, Project_Account_Relation__c> oldPARsByIds) {
        this.oldPARsByIds = oldPARsByIds;
        return this;
    }

    /**
     * Chain-Method to build the Handler
     *
     * @param newPARsByIds New ProjectAccountRelation-Maps is mandatory
     *
     * @return DUPProjectAccountRelationHandler
     */
    public DUPProjectAccountRelationHandler addNewPARs(Map<Id, Project_Account_Relation__c> newPARsByIds) {
        this.newPARsByIds = newPARsByIds;
        return this;
    }

    /**
     * To choose async execution-context
     */
    public enum JobContext {
        ON_INSERT,
        ON_UPDATE,
        ON_DELETE,
        ON_UNDELETE
    }

    /**
     * Async execution methode
     *
     * @param context JobContext is mandatory to chose execution-context
     */
    public void executeJob(JobContext context) {
        DUPProjectAccountRelationHandlerJob dupPARQueueable = new DUPProjectAccountRelationHandlerJob(this, context);

        if (
            context == JobContext.ON_UPDATE &&
            (this.oldPARsByIds == null ||
            this.newPARsByIds == null ||
            this.newPARsByIds.isEmpty())
        ) {
            throw new DUPProjectAccountRelationHandlerException('Project Account Relation not properly initiated.');
        } else if (
            context == JobContext.ON_INSERT &&
            (this.newPARsByIds == null ||
            this.newPARsByIds.isEmpty())
        ) {
            throw new DUPProjectAccountRelationHandlerException('Project Account Relation not properly initiated.');
        } else if (
            context == JobContext.ON_DELETE &&
            (this.oldPARsByIds == null ||
            this.oldPARsByIds.isEmpty())
        ) {
            throw new DUPProjectAccountRelationHandlerException('Project Account Relation not properly initiated.');
        } else if (
            context == JobContext.ON_UNDELETE &&
            (this.newPARsByIds == null ||
            this.newPARsByIds.isEmpty())
        ) {
            throw new DUPProjectAccountRelationHandlerException('Project Account Relation not properly initiated.');
        } else {
            UTLQueueableUtility.enqueueJob(dupPARQueueable);
        }
    }

    /**
     * To execute the outer class in an async context.
     */
    private class DUPProjectAccountRelationHandlerJob implements Queueable {
        private String CLASSNAME = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));

        private JobContext context;

        private DUPProjectAccountRelationHandler dupPARHandler;

        private DUPProjectAccountRelationHandlerJob(DUPProjectAccountRelationHandler dupPARHandler, JobContext context) {
            this.dupPARHandler = dupPARHandler;
            this.context = context;
        }

        public void execute(QueueableContext qc) {
            try {
                switch on Context {
                    when ON_INSERT {
                        dupPARHandler.handlePARInsertAsync();
                    }
                    when ON_UPDATE {
                        dupPARHandler.handlePARChangeAsync();
                    }
                    when ON_DELETE {
                        dupPARHandler.handlePARDeleteAsync();
                    }
                    when ON_UNDELETE {
                        dupPARHandler.handlePARUndeleteAsync();
                    }
                    when else {
                        throw new DUPProjectAccountRelationHandlerException('Unknown JobContext');
                    }
                }
            } catch (Exception e) {
                UTLErrorLog.insertErrorLogs(
                    new List<Core_Error_Log__c>{
                        UTLErrorLog.createErrorLogRecord(
                            this.CLASSNAME,
                            e,
                            'Queueable-Execution-Error on ProjectAccountRelation Handling',
                            qc.getJobId()
                        )
                    },
                    this.CLASSNAME
                );
            }
        }
    }

    /**
     * Async handling for Insert
     */
    private void handlePARInsertAsync() {
        handleProjectHelperFieldChangeOnInsert(this.newPARsByIds);

        //handle DUPPARHandlerExceptions
        if (!this.DUPPARHandlerExceptions.isEmpty()) {
            UTLErrorLog.insertErrorLogs(createsExceptionLogs(this.DUPPARHandlerExceptions), CLASSNAME);
        }
    }

    /**
     * Async handling for Change
     */
    private void handlePARChangeAsync() {
        handleProjectHelperFieldChangeOnUpdate(this.oldPARsByIds, this.newPARsByIds);

        //handle DUPPARHandlerExceptions
        if (!this.DUPPARHandlerExceptions.isEmpty()) {
            UTLErrorLog.insertErrorLogs(createsExceptionLogs(this.DUPPARHandlerExceptions), CLASSNAME);
        }
    }

    /**
     * Async handling for Delete
     */
    private void handlePARDeleteAsync() {
        handleProjectHelperFieldChangeOnDelete(this.oldPARsByIds);

        //handle DUPPARHandlerExceptions
        if (!this.DUPPARHandlerExceptions.isEmpty()) {
            UTLErrorLog.insertErrorLogs(createsExceptionLogs(this.DUPPARHandlerExceptions), CLASSNAME);
        }
    }

    /**
     * Async handling for Undelete
     */
    private void handlePARUndeleteAsync() {
        handleProjectHelperFieldChangeOnUndelete(this.newPARsByIds);

        //handle DUPPARHandlerExceptions
        if (!this.DUPPARHandlerExceptions.isEmpty()) {
            UTLErrorLog.insertErrorLogs(createsExceptionLogs(this.DUPPARHandlerExceptions), CLASSNAME);
        }
    }

    /**
     * Update project helper field changes on afterInsert
     */
    private void handleProjectHelperFieldChangeOnInsert(Map<Id, Project_Account_Relation__c> newPARsByIds) {
        List<Project__c> projects2Update = new List<Project__c>();
        Map<Id, Project__c> projects2UpdateMap = new Map<Id, Project__c>();
        Map<Id, Project__c> newRelatedProjects = getRelatedProjectsMap(newPARsByIds);
        Map<Id, Account> newAccountsMap = getRelatedAccountsMapByIds(newPARsByIds);
        List<String> accountRoleOptions = DUPDuplicateCheckHelper.getPicklistFieldOptions(PROJECT_ACCOUNT_RELATION_SOBJECT_API_NAME, ACCOUNT_ROLE_FIELD_API_NAME);

        try {
            for(Project_Account_Relation__c newPAR : newPARsByIds.values()) {            
                //check if related project was updated for another Project Project_Account_Relation__c record to prevent "Duplicate id in list" error
                Project__c newRelatedProject = new Project__c();
                if(projects2UpdateMap.containsKey(newPAR.Project__c)) {
                    newRelatedProject = projects2UpdateMap.get(newPAR.Project__c);
                } else {
                    newRelatedProject = newRelatedProjects.get(newPAR.Project__c);
                }

                //format account name
                String newInvolvedAccountName = DUPDuplicateCheckHelper.formatAccountName(newAccountsMap.get(newPAR.Account__c).Name);
                List<String> newAccountRoles = DUPDuplicateCheckHelper.formatConcatenatedStringToList(newPAR.Account_Role__c, ';');

                //Prepare Building owner helper field, if building owner is added
                if(newPAR.Account_Role__c != null && 
                newPAR.Account_Role__c.contains('3')) {
                    newRelatedProject.Building_Owner_cleaned__c = newInvolvedAccountName;
                    newRelatedProject.Building_Owner__c = newAccountsMap.get(newPAR.Account__c).Name;
                }
                //Prepare Involved Accounts helper field, if any other role than Building Owner is selected
                if(DUPDuplicateCheckHelper.containsCommonValue(accountRoleOptions, newAccountRoles) ||
                newPAR.Account_Role__c == null) {
                    newRelatedProject.Involved_Accounts_cleaned__c = DUPDuplicateCheckHelper.addValueToConcatenatedString(newRelatedProject.Involved_Accounts_cleaned__c, newInvolvedAccountName);
                }

                //set Automation_Time__c to pass by validation rule 
                newRelatedProject.Automation_Time__c = System.now();
                projects2UpdateMap.put(newRelatedProject.Id, newRelatedProject);
            } 

            //update helper fields on project
            projects2Update.addAll(projects2UpdateMap.values());
            updateProjectRecords(projects2Update);

        } catch (Exception e) {
            createExceptionsPerPAR(e, newPARsByIds);
        }
    }

    /**
     * Update project helper field changes on afterUpdate
     */
    private void handleProjectHelperFieldChangeOnUpdate(Map<Id, Project_Account_Relation__c> oldPARsByIds, Map<Id, Project_Account_Relation__c> newPARsByIds) {
        List<Project__c> projects2Update = new List<Project__c>();
        Map<Id, Project__c> projects2UpdateMap = new Map<Id, Project__c>();
        Map<Id, Project__c> oldRelatedProjects = getRelatedProjectsMap(oldPARsByIds);
        Map<Id, Project__c> newRelatedProjects = getRelatedProjectsMap(newPARsByIds);
        Map<Id, Account> oldAccountsMap = getRelatedAccountsMapByIds(oldPARsByIds);
        Map<Id, Account> newAccountsMap = getRelatedAccountsMapByIds(newPARsByIds);
        Map<Id, List<Project_Account_Relation__c>> buildingOwnersByProjectIdMap =  getBuildingOwnersByProjectIdMap(oldRelatedProjects.keySet());
        Map<Id, List<Project_Account_Lead_Relation__c>> buildingOwnerLeadsByProjectIdMap =  getBuildingOwnerLeadsByProjectIdMap(oldRelatedProjects.keySet());
        List<String> accountRoleOptions = DUPDuplicateCheckHelper.getPicklistFieldOptions(PROJECT_ACCOUNT_RELATION_SOBJECT_API_NAME, ACCOUNT_ROLE_FIELD_API_NAME);
        
        try {
            for(Project_Account_Relation__c newPAR : newPARsByIds.values()) {
                Project_Account_Relation__c oldPAR = oldPARsByIds.get(newPAR.Id);

                //check if related project was updated for another Project Project_Account_Relation__c record to prevent "Duplicate id in list" error
                Project__c oldRelatedProject = new Project__c();
                Project__c newRelatedProject = new Project__c();
                if(projects2UpdateMap.containsKey(oldPAR.Project__c)) {
                    oldRelatedProject = projects2UpdateMap.get(oldPAR.Project__c);
                } else {
                    oldRelatedProject = oldRelatedProjects.get(oldPAR.Project__c);
                }
                if(projects2UpdateMap.containsKey(newPAR.Project__c)) {
                    newRelatedProject = projects2UpdateMap.get(newPAR.Project__c);
                } else {
                    newRelatedProject = newRelatedProjects.get(newPAR.Project__c);
                }

                //format account name and role
                String newInvolvedAccountFullName = newAccountsMap.get(newPAR.Account__c).Name;
                String oldInvolvedAccountName = DUPDuplicateCheckHelper.formatAccountName(oldAccountsMap.get(oldPAR.Account__c).Name);
                String newInvolvedAccountName = DUPDuplicateCheckHelper.formatAccountName(newInvolvedAccountFullName);
                List<String> oldAccountRoles = DUPDuplicateCheckHelper.formatConcatenatedStringToList(oldPAR.Account_Role__c, ';');
                List<String> newAccountRoles = DUPDuplicateCheckHelper.formatConcatenatedStringToList(newPAR.Account_Role__c, ';');
                //Count how many non-Building Owner Roles were selected before the update
                Boolean oldPARHasNonBusinessOwnerRole = DUPDuplicateCheckHelper.containsCommonValue(accountRoleOptions, oldAccountRoles);
                //Count how many non-Building Owner Roles were selected after the update
                Boolean newPARHasNonBusinessOwnerRole = DUPDuplicateCheckHelper.containsCommonValue(accountRoleOptions, newAccountRoles);

                //Handle scenario if project is not changed
                if(oldPAR.Project__c == newPar.Project__c) {
                    //Prepare helper fields on related project in following scenarios
                    //1.1   Building Owner Role was removed and no other building owner exists
                    if(oldPAR.Account_Role__c != null && 
                    oldAccountRoles.contains('3') &&
                    newPar.Account_Role__c != null && 
                    !newAccountRoles.contains('3') && 
                    (buildingOwnersByProjectIdMap.isEmpty() || (!buildingOwnersByProjectIdMap.isEmpty() && buildingOwnersByProjectIdMap.get(oldPAR.Project__c) == null)) && 
                    (buildingOwnerLeadsByProjectIdMap.isEmpty() || (!buildingOwnerLeadsByProjectIdMap.isEmpty() && buildingOwnerLeadsByProjectIdMap.get(oldPAR.Project__c) == null))) {
                        oldRelatedProject.Building_Owner_cleaned__c = '';
                        oldRelatedProject.Building_Owner__c = ''; 
                    //1.2   Building Owner Role was removed and other building owner exists for this project
                    } else if(oldPAR.Account_Role__c != null && 
                    oldAccountRoles.contains('3') &&
                    newPar.Account_Role__c != null && 
                    !newAccountRoles.contains('3') && 
                    !buildingOwnersByProjectIdMap.isEmpty() && 
                    buildingOwnersByProjectIdMap.get(oldPAR.Project__c) != null) {
                        String oldBuildingOwnerName = DUPDuplicateCheckHelper.formatAccountName(buildingOwnersByProjectIdMap.get(oldPAR.Project__c)[0].Account__r.Name);
                        oldRelatedProject.Building_Owner_cleaned__c = oldBuildingOwnerName;
                        oldRelatedProject.Building_Owner__c = buildingOwnersByProjectIdMap.get(oldPAR.Project__c)[0].Account__r.Name;
                    } else if(oldPAR.Account_Role__c != null && 
                    oldAccountRoles.contains('3') &&
                    newPar.Account_Role__c != null && 
                    !newAccountRoles.contains('3') && 
                    (buildingOwnersByProjectIdMap.isEmpty() || (!buildingOwnersByProjectIdMap.isEmpty() && buildingOwnersByProjectIdMap.get(oldPAR.Project__c) == null)) && 
                    !buildingOwnerLeadsByProjectIdMap.isEmpty()  && 
                    buildingOwnerLeadsByProjectIdMap.get(oldPAR.Project__c)[0].Account_Lead__r.Name != null
                    ) {
                        String oldBuildingOwnerName = DUPDuplicateCheckHelper.formatAccountName(buildingOwnerLeadsByProjectIdMap.get(oldPAR.Project__c)[0].Account_Lead__r.Name);
                        oldRelatedProject.Building_Owner_cleaned__c = oldBuildingOwnerName;
                        oldRelatedProject.Building_Owner__c = buildingOwnerLeadsByProjectIdMap.get(oldPAR.Project__c)[0].Account_Lead__r.Name;
                    }
                    //1.3   Building Owner Role was added, or stays the same and only Account is changed
                    else if(newPar.Account_Role__c != null && 
                    newAccountRoles.contains('3')) {
                        oldRelatedProject.Building_Owner_cleaned__c = newInvolvedAccountName;
                        oldRelatedProject.Building_Owner__c = newInvolvedAccountFullName;
                    }

                    //2.1   Last non-Building Owner Role was removed (replaced by another or set to null)
                    if(oldPARHasNonBusinessOwnerRole &&
                    (! newPARHasNonBusinessOwnerRole  ||
                    newPAR.Account_Role__c == null)) {
                        oldRelatedProject.Involved_Accounts_cleaned__c = DUPDuplicateCheckHelper.removeValueInConcatenatedString(oldRelatedProject.Involved_Accounts_cleaned__c, oldInvolvedAccountName);
                    } 
                    //2.2   First non-Building Owner Role was added
                    else if((! oldPARHasNonBusinessOwnerRole || 
                    oldPAR == null) && 
                    newPARHasNonBusinessOwnerRole) {
                        oldRelatedProject.Involved_Accounts_cleaned__c = DUPDuplicateCheckHelper.addValueToConcatenatedString(oldRelatedProject.Involved_Accounts_cleaned__c, newInvolvedAccountName);
                    } 
                    //2.3   Non-Building Owner Role stays the same, only Account is changed
                    else if((oldPARHasNonBusinessOwnerRole &&
                    newPARHasNonBusinessOwnerRole) ||
                    (oldPAR.Account_Role__c == null && 
                    newPar.Account_Role__c == null)
                    ) {
                        oldRelatedProject.Involved_Accounts_cleaned__c = DUPDuplicateCheckHelper.replaceValueInConcatenatedString(oldRelatedProject.Involved_Accounts_cleaned__c, oldInvolvedAccountName, newInvolvedAccountName);
                    }
                //Handle project change
                } else {
                    //3.1   Remove PAR references on old project
                    if(oldPAR.Account_Role__c != null &&
                    oldAccountRoles.contains('3')) {
                        oldRelatedProject.Building_Owner_cleaned__c = '';
                        oldRelatedProject.Building_Owner__c = '';
                    }
                    if(oldPARHasNonBusinessOwnerRole ||
                    oldPAR.Account_Role__c == null) {
                        oldRelatedProject.Involved_Accounts_cleaned__c = DUPDuplicateCheckHelper.removeValueInConcatenatedString(oldRelatedProject.Involved_Accounts_cleaned__c, oldInvolvedAccountName);
                    }

                    //3.2   Add PAR references on new project
                    if(newPAR.Account_Role__c != null &&
                    newAccountRoles.contains('3')) {
                        newRelatedProject.Building_Owner_cleaned__c = newInvolvedAccountName;
                        newRelatedProject.Building_Owner__c = newInvolvedAccountFullName;
                    }
                    if(newPARHasNonBusinessOwnerRole || 
                    newPAR.Account_Role__c == null) {
                        newRelatedProject.Involved_Accounts_cleaned__c = DUPDuplicateCheckHelper.addValueToConcatenatedString(newRelatedProject.Involved_Accounts_cleaned__c, newInvolvedAccountName);
                    }

                    //set Automation_Time__c to pass by validation rule 
                    newRelatedProject.Automation_Time__c = System.now();
                    projects2UpdateMap.put(newRelatedProject.Id, newRelatedProject);
                }

                projects2UpdateMap.put(oldRelatedProject.Id, oldRelatedProject);
            } 

            //update helper fields on project
            projects2Update.addAll(projects2UpdateMap.values());
            updateProjectRecords(projects2Update);

        } catch (Exception e) {
            createExceptionsPerPAR(e, newPARsByIds);
        }
    }

    /**
     * Update project helper field changes on afterDelete
     */
    private void handleProjectHelperFieldChangeOnDelete(Map<Id, Project_Account_Relation__c> oldPARsByIds) {
        List<Project__c> projects2Update = new List<Project__c>();
        Map<Id, Project__c> projects2UpdateMap = new Map<Id, Project__c>();
        Map<Id, Project__c> oldRelatedProjects = getRelatedProjectsMap(oldPARsByIds);
        Map<Id, Account> oldAccountsMap = getRelatedAccountsMapByIds(oldPARsByIds);
        Map<Id, List<Project_Account_Relation__c>> buildingOwnersByProjectIdMap =  getBuildingOwnersByProjectIdMap(oldRelatedProjects.keySet());
        Map<Id, List<Project_Account_Lead_Relation__c>> buildingOwnerLeadsByProjectIdMap =  getBuildingOwnerLeadsByProjectIdMap(oldRelatedProjects.keySet());
        List<String> accountRoleOptions = DUPDuplicateCheckHelper.getPicklistFieldOptions(PROJECT_ACCOUNT_RELATION_SOBJECT_API_NAME, ACCOUNT_ROLE_FIELD_API_NAME);

        try {
            for(Project_Account_Relation__c oldPAR : oldPARsByIds.values()) {
                //check if related project was updated for another Project Project_Account_Relation__c record to prevent "Duplicate id in list" error
                Project__c oldRelatedProject = new Project__c();
                if(projects2UpdateMap.containsKey(oldPAR.Project__c)) {
                    oldRelatedProject = projects2UpdateMap.get(oldPAR.Project__c);
                } else {
                    oldRelatedProject = oldRelatedProjects.get(oldPAR.Project__c);
                }

                //format account name
                String oldInvolvedAccountName = DUPDuplicateCheckHelper.formatAccountName(oldAccountsMap.get(oldPAR.Account__c).Name);
                List<String> oldAccountRoles = DUPDuplicateCheckHelper.formatConcatenatedStringToList(oldPAR.Account_Role__c, ';');

                //Clear account from helper fields on related project
                //1.1   project has no other building owner assigned
                if(oldPAR.Account_Role__c != null &&
                oldAccountRoles.contains('3') &&
                (buildingOwnersByProjectIdMap.isEmpty() || (!buildingOwnersByProjectIdMap.isEmpty() && buildingOwnersByProjectIdMap.get(oldPAR.Project__c) == null)) &&
                (buildingOwnerLeadsByProjectIdMap.isEmpty() || (!buildingOwnerLeadsByProjectIdMap.isEmpty() && buildingOwnerLeadsByProjectIdMap.get(oldPAR.Project__c) == null))) {
                    oldRelatedProject.Building_Owner_cleaned__c = '';
                    oldRelatedProject.Building_Owner__c = '';
                //1.2   other building owner exists for this project, so replace deleted building owner by other value
                } else if(oldPAR.Account_Role__c != null &&
                oldAccountRoles.contains('3') &&
                !buildingOwnersByProjectIdMap.isEmpty() && 
                buildingOwnersByProjectIdMap.get(oldPAR.Project__c) != null) {
                    String oldBuildingOwnerName = DUPDuplicateCheckHelper.formatAccountName(buildingOwnersByProjectIdMap.get(oldPAR.Project__c)[0].Account__r.Name);
                    oldRelatedProject.Building_Owner_cleaned__c = oldBuildingOwnerName;
                    oldRelatedProject.Building_Owner__c = buildingOwnersByProjectIdMap.get(oldPAR.Project__c)[0].Account__r.Name;
                } else if(oldPAR.Account_Role__c != null &&          
                oldAccountRoles.contains('3') &&
                (buildingOwnersByProjectIdMap.isEmpty() || (!buildingOwnersByProjectIdMap.isEmpty() && buildingOwnersByProjectIdMap.get(oldPAR.Project__c) == null)) && 
                !buildingOwnerLeadsByProjectIdMap.isEmpty() && 
                buildingOwnerLeadsByProjectIdMap.get(oldPAR.Project__c) != null
                ) {
                    String oldBuildingOwnerName = DUPDuplicateCheckHelper.formatAccountName(buildingOwnerLeadsByProjectIdMap.get(oldPAR.Project__c)[0].Account_Lead__r.Name);
                    oldRelatedProject.Building_Owner_cleaned__c = oldBuildingOwnerName;
                    oldRelatedProject.Building_Owner__c = buildingOwnerLeadsByProjectIdMap.get(oldPAR.Project__c)[0].Account_Lead__r.Name;
                }
                //1.3   remove involved account record if non-building owner role or no role is assigned
                if(DUPDuplicateCheckHelper.containsCommonValue(accountRoleOptions, oldAccountRoles) ||
                oldPAR.Account_Role__c == null) {
                    oldRelatedProject.Involved_Accounts_cleaned__c = DUPDuplicateCheckHelper.removeValueInConcatenatedString(oldRelatedProject.Involved_Accounts_cleaned__c, oldInvolvedAccountName);
                }                
                
                //set Automation_Time__c to pass by validation rule 
                oldRelatedProject.Automation_Time__c = System.now();
                projects2UpdateMap.put(oldRelatedProject.Id, oldRelatedProject);
            } 

            //update helper fields on project
            projects2Update.addAll(projects2UpdateMap.values());
            updateProjectRecords(projects2Update);

        } catch (Exception e) {
            createExceptionsPerPAR(e, oldPARsByIds);
        }
    }

    /**
     * Update project helper field changes on afterUndelete
     */
    private void handleProjectHelperFieldChangeOnUndelete(Map<Id, Project_Account_Relation__c> newPARsByIds) {
        List<Project__c> projects2Update = new List<Project__c>();
        Map<Id, Project__c> projects2UpdateMap = new Map<Id, Project__c>();
        Map<Id, Project__c> newRelatedProjects = getRelatedProjectsMap(newPARsByIds);
        Map<Id, Account> newAccountsMap = getRelatedAccountsMapByIds(newPARsByIds);
        List<String> accountRoleOptions = DUPDuplicateCheckHelper.getPicklistFieldOptions(PROJECT_ACCOUNT_RELATION_SOBJECT_API_NAME, ACCOUNT_ROLE_FIELD_API_NAME);

        try {
            for(Project_Account_Relation__c newPAR : newPARsByIds.values()) {
                //check if related project was updated for another Project Project_Account_Relation__c record to prevent "Duplicate id in list" error
                Project__c newRelatedProject = new Project__c();
                if(projects2UpdateMap.containsKey(newPAR.Project__c)) {
                    newRelatedProject = projects2UpdateMap.get(newPAR.Project__c);
                } else {
                    newRelatedProject = newRelatedProjects.get(newPAR.Project__c);
                }

                //format account name
                String newInvolvedAccountFullName = newAccountsMap.get(newPAR.Account__c).Name;
                String newInvolvedAccountName = DUPDuplicateCheckHelper.formatAccountName(newInvolvedAccountFullName);
                List<String> newAccountRoles = DUPDuplicateCheckHelper.formatConcatenatedStringToList(newPAR.Account_Role__c, ';');

                //Prepare Building owner helper field, if building owner is added
                if(newPAR.Account_Role__c != null &&
                newAccountRoles.contains('3')) {
                    newRelatedProject.Building_Owner_cleaned__c = newInvolvedAccountName;
                    newRelatedProject.Building_Owner__c = newInvolvedAccountFullName;
                }
                //Prepare Involved Accounts helper field, if any other role than Building Owner is selected
                if(DUPDuplicateCheckHelper.containsCommonValue(accountRoleOptions, newAccountRoles) ||
                newPAR.Account_Role__c == null) {
                    newRelatedProject.Involved_Accounts_cleaned__c = DUPDuplicateCheckHelper.addValueToConcatenatedString(newRelatedProject.Involved_Accounts_cleaned__c, newInvolvedAccountName);
                }
                                
                //set Automation_Time__c to pass by validation rule 
                newRelatedProject.Automation_Time__c = System.now();
                projects2UpdateMap.put(newRelatedProject.Id, newRelatedProject);
            } 

            //update helper fields on project
            projects2Update.addAll(projects2UpdateMap.values());
            updateProjectRecords(projects2Update);

            if(Test.isRunningTest()) {
                throw new DMLException('Test Exception');
            }

        } catch (Exception e) {
            createExceptionsPerPAR(e, newPARsByIds);
        }
    }

    /**
     * Helper method to update project records, on which helper fields were updated
     * 
     * @param projects2Update list of projects to be updated
     * 
     * @return String of concatenated values including replaced value
     */
    private void updateProjectRecords(List<Project__c> projects2Update) {  
        //update helper fields on project
        if(!projects2Update.isEmpty()) {
            Database.SaveResult[] projectUpdateResult = Database.update(projects2Update, false);
            
            // check results and create rerror logs
            Integer i = 0;
            for (Database.SaveResult sr : projectUpdateResult) {
                if (!sr.isSuccess()) {
                    Id projId = projects2Update[i].Id;

                    String errorMessage = 'Error while updating Project__c record with ID ' + projId;
                    String exceptionMessage = sr.getErrors()[0].getStatusCode() + ': ' + sr.getErrors()[0].getMessage();

                    System.debug('########## RP exceptionMessage: ' + exceptionMessage);
                    this.DUPPARHandlerExceptions.put(
                        projId,
                        new DUPProjectAccountRelationHandlerException('Processing error: ' + exceptionMessage)
                    );
                }
                i++;
            }
        }
    }

    /**
     * Get Project-Map of all related projects, for future processing.
     * 
     * @return Projects mapped by Record Id 
     */
    private Map<Id, Project__c> getRelatedProjectsMap(Map<Id, Project_Account_Relation__c> newPARsByIds) {
        Set<Id> relatedProjectIds = new Set<Id>();
        
        for(Project_Account_Relation__c newPAR : newPARsByIds.values()) {
            relatedProjectIds.add(newPAR.Project__c);
        }

        Map<Id, Project__c> oldRelatedProjects = new Map<Id, Project__c>(
            [
                SELECT 
                    Id, 
                    Building_Owner_cleaned__c, 
                    Building_Owner__c,
                    Involved_Accounts_cleaned__c
                FROM Project__c
                WHERE Id IN :relatedProjectIds
            ]
        );

        return oldRelatedProjects;
    }

    /**
     * Get Account-Map of all related accounts, for future processing.
     * 
     * @return Projects mapped by Record Id 
     */
    private Map<Id, Account> getRelatedAccountsMapByIds(Map<Id, Project_Account_Relation__c> parsByIds) {
        Set<Id> relatedAccountIds = new Set<Id>();
        
        for(Project_Account_Relation__c par : parsByIds.values()) {
            relatedAccountIds.add(par.Account__c);
        }

        Map<Id, Account> relatedAccountsMap = new Map<Id, Account>(
            [
                SELECT 
                    Id, 
                    Name
                FROM Account
                WHERE Id IN :relatedAccountIds
            ]
        );

        return relatedAccountsMap;
    }

    /**
     * Get Building Owners By Project Id-Map of all related projects, for future processing.
     *      
     * @param relatedProjectIds set of project ids
     * 
     * @return Projects mapped by Record Id 
     */
    private Map<Id, List<Project_Account_Relation__c>> getBuildingOwnersByProjectIdMap(Set<Id> relatedProjectIds) {
        Map<Id, List<Project_Account_Relation__c>> buildingOwnersByProjectIdMap = new Map<Id, List<Project_Account_Relation__c>>();
        
        for(Project_Account_Relation__c buildingOwner : [SELECT 
                                                            Id, 
                                                            Account__c, 
                                                            Account__r.Name, 
                                                            Project__c, 
                                                            Account_Role__c                                                     
                                                        FROM Project_Account_Relation__c
                                                        WHERE Project__c IN :relatedProjectIds
                                                        AND Account_Role__c IN ('3')]) {
            if(!buildingOwnersByProjectIdMap.containsKey(buildingOwner.Project__c)) {
                List<Project_Account_Relation__c> buildingOwnerList = new List<Project_Account_Relation__c>{buildingOwner};
                buildingOwnersByProjectIdMap.put(buildingOwner.Project__c, buildingOwnerList);
            } else {
                List<Project_Account_Relation__c> buildingOwnerList = buildingOwnersByProjectIdMap.get(buildingOwner.Project__c);
                buildingOwnerList.add(buildingOwner);
                buildingOwnersByProjectIdMap.put(buildingOwner.Project__c, buildingOwnerList);
            }
        }

        return buildingOwnersByProjectIdMap;
    }

    /**
     * Get Building Owner Leads By Project Id-Map of all related projects, for future processing.
     * 
     * @param relatedProjectIds set of project ids
     * 
     * @return Projects mapped by Record Id 
     */
    private Map<Id, List<Project_Account_Lead_Relation__c>> getBuildingOwnerLeadsByProjectIdMap(Set<Id> relatedProjectIds) {
        Map<Id, List<Project_Account_Lead_Relation__c>> buildingOwnersByProjectIdMap = new Map<Id, List<Project_Account_Lead_Relation__c>>();
        
        for(Project_Account_Lead_Relation__c buildingOwner : [SELECT 
                                                                Id, 
                                                                Account_Lead__c, 
                                                                Account_Lead__r.Name, 
                                                                Project__c, 
                                                                Account_Role__c 
                                                            FROM Project_Account_Lead_Relation__c
                                                            WHERE Project__c IN :relatedProjectIds
                                                            AND Account_Role__c IN ('3')]) {
            if(!buildingOwnersByProjectIdMap.containsKey(buildingOwner.Project__c)) {
                List<Project_Account_Lead_Relation__c> buildingOwnerList = new List<Project_Account_Lead_Relation__c>{buildingOwner};
                buildingOwnersByProjectIdMap.put(buildingOwner.Project__c, buildingOwnerList);
            } else {
                List<Project_Account_Lead_Relation__c> buildingOwnerList = buildingOwnersByProjectIdMap.get(buildingOwner.Project__c);
                buildingOwnerList.add(buildingOwner);
                buildingOwnersByProjectIdMap.put(buildingOwner.Project__c, buildingOwnerList);
            }
        }

        return buildingOwnersByProjectIdMap;
    }

    /**
     * Creates Exceptions mapped by ProjectAccountRelation Ids
     *
     * @param e Single Exception to replicate by ProjectAccountRelation-Id
     * @param newPARsByIds ProjectAccountRelation-Map
     */
    private void createExceptionsPerPAR(Exception e, Map<Id, Project_Account_Relation__c> newPARsByIds) {
        for (Id parId : newPARsByIds.keySet()) {
            this.DUPPARHandlerExceptions.put(parId, new DUPProjectAccountRelationHandlerException(e.getMessage()));
        }
    }

    /**
     * Maps DUPProjectAccountRelationHandlerException and ProjectAccountRelation-Id's to a List of Core_Error_Log__c.
     *
     * @param dupPARHandlerExceptionsByPARIds created Core_Error_Log__c list
     *
     * @return List of Core_Error_Log__c
     */
    private List<Core_Error_Log__c> createsExceptionLogs(Map<Id, DUPProjectAccountRelationHandlerException> dupPARHandlerExceptionsByPARIds) {
        List<Core_Error_Log__c> coreErrorLogs = new List<Core_Error_Log__c>();

        for (Id parId : dupPARHandlerExceptionsByPARIds.keySet()) {
            DUPProjectAccountRelationHandlerException dUPPARHandlerException = dupPARHandlerExceptionsByPARIds.get(parId);

            System.debug('Exception occured:');
            System.debug('Message:' + dUPPARHandlerException.getMessage());
            System.debug('Stack:' + dUPPARHandlerException.getStackTraceString());
            System.debug('Line:' + dUPPARHandlerException.getLineNumber());

            Core_Error_Log__c coreErrorLog = UTLErrorLog.createErrorLogRecord(
                CLASSNAME,
                dUPPARHandlerException,
                'Error on ProjectAccountRelation Handling',
                parId
            );
            coreErrorLogs.add(coreErrorLog);
        }
        return coreErrorLogs;
    }

    public class DUPProjectAccountRelationHandlerException extends Exception {
    }
}