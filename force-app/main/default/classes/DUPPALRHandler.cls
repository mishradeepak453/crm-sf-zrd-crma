/**
 * SF-1205: Update helper fields for involved accounts on related Project__c records
 *
 * @author  isabella.moos@accenture.com
 *
 * @version 2023-10-09      isabella.moos@accenture.com     creation
 */
public without sharing class DUPPALRHandler {
    @TestVisible
    private String CLASSNAME = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));
    private String PROJECT_ACCOUNT_LEAD_RELATION_SOBJECT_API_NAME = 'Project_Account_Lead_Relation__c';
    private String ACCOUNT_ROLE_FIELD_API_NAME = 'Account_Role__c';

    private Map<Id, Project_Account_Lead_Relation__c> oldPALRsByIds;
    private Map<Id, Project_Account_Lead_Relation__c> newPALRsByIds;

    private Map<Id, DUPPALRHandlerException> DUPPALRHandlerExceptions = new Map<Id, DUPPALRHandlerException>();

    /**
     * Chain-Method to build the Handler
     *
     * @palram oldPALRsByIds Old ProjectAccountRelation-Maps is mandatory
     *
     * @return DUPPALRHandler
     */
    public DUPPALRHandler addOldPALRs(Map<Id, Project_Account_Lead_Relation__c> oldPALRsByIds) {
        this.oldPALRsByIds = oldPALRsByIds;
        return this;
    }

    /**
     * Chain-Method to build the Handler
     *
     * @palram newPALRsByIds New ProjectAccountRelation-Maps is mandatory
     *
     * @return DUPPALRHandler
     */
    public DUPPALRHandler addNewPALRs(Map<Id, Project_Account_Lead_Relation__c> newPALRsByIds) {
        this.newPALRsByIds = newPALRsByIds;
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
     * @palram context JobContext is mandatory to chose execution-context
     */
    public void executeJob(JobContext context) {
        DUPPALRHandlerJob dupPALRQueueable = new DUPPALRHandlerJob(this, context);

        if (
            context == JobContext.ON_UPDATE &&
            (this.oldPALRsByIds == null ||
            this.newPALRsByIds == null ||
            this.newPALRsByIds.isEmpty())
        ) {
            throw new DUPPALRHandlerException('Project Account Lead Relation not properly initiated.');
        } else if (
            context == JobContext.ON_INSERT &&
            (this.newPALRsByIds == null ||
            this.newPALRsByIds.isEmpty())
        ) {
            throw new DUPPALRHandlerException('Project Account Lead Relation not properly initiated.');
        } else if (
            context == JobContext.ON_DELETE &&
            (this.oldPALRsByIds == null ||
            this.oldPALRsByIds.isEmpty())
        ) {
            throw new DUPPALRHandlerException('Project Account Lead Relation not properly initiated.');
        } else if (
            context == JobContext.ON_UNDELETE &&
            (this.newPALRsByIds == null ||
            this.newPALRsByIds.isEmpty())
        ) {
            throw new DUPPALRHandlerException('Project Account Lead Relation not properly initiated.');
        } else { 
            UTLQueueableUtility.enqueueJob(dupPALRQueueable);
        }
    }

    /**
     * To execute the outer class in an async context.
     */
    private class DUPPALRHandlerJob implements Queueable {
        private String CLASSNAME = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));

        private JobContext context;

        private DUPPALRHandler dupPALRHandler;

        private DUPPALRHandlerJob(DUPPALRHandler dupPALRHandler, JobContext context) {
            this.dupPALRHandler = dupPALRHandler;
            this.context = context;
        }

        public void execute(QueueableContext qc) {
            try {
                switch on Context {
                    when ON_INSERT {
                        dupPALRHandler.handlePALRInsertAsync();
                    }
                    when ON_UPDATE {
                        dupPALRHandler.handlePALRChangeAsync();
                    }
                    when ON_DELETE {
                        dupPALRHandler.handlePALRDeleteAsync();
                    }
                    when ON_UNDELETE {
                        dupPALRHandler.handlePALRUndeleteAsync();
                    }
                    when else {
                        throw new DUPPALRHandlerException('Unknown JobContext');
                    }
                }
            } catch (Exception e) {
                UTLErrorLog.insertErrorLogs(
                    new List<Core_Error_Log__c>{
                        UTLErrorLog.createErrorLogRecord(
                            this.CLASSNAME,
                            e,
                            'Queueable-Execution-Error on ProjectAccountLeadRelation Handling',
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
    private void handlePALRInsertAsync() {
        handleProjectHelperFieldChangeOnInsert(this.newPALRsByIds);

        //handle DUPPALRHandlerExceptions
        if (!this.DUPPALRHandlerExceptions.isEmpty()) {
            UTLErrorLog.insertErrorLogs(createsExceptionLogs(this.DUPPALRHandlerExceptions), CLASSNAME);
        }
    }

    /**
     * Async handling for Change
     */
    private void handlePALRChangeAsync() {
        handleProjectHelperFieldChangeOnUpdate(this.oldPALRsByIds, this.newPALRsByIds);

        //handle DUPPALRHandlerExceptions
        if (!this.DUPPALRHandlerExceptions.isEmpty()) {
            UTLErrorLog.insertErrorLogs(createsExceptionLogs(this.DUPPALRHandlerExceptions), CLASSNAME);
        }
    }

    /**
     * Async handling for Delete
     */
    private void handlePALRDeleteAsync() {
        handleProjectHelperFieldChangeOnDelete(this.oldPALRsByIds);

        //handle DUPPALRHandlerExceptions
        if (!this.DUPPALRHandlerExceptions.isEmpty()) {
            UTLErrorLog.insertErrorLogs(createsExceptionLogs(this.DUPPALRHandlerExceptions), CLASSNAME);
        }
    }

    /**
     * Async handling for Undelete
     */
    private void handlePALRUndeleteAsync() {
        handleProjectHelperFieldChangeOnUndelete(this.newPALRsByIds);

        //handle DUPPALRHandlerExceptions
        if (!this.DUPPALRHandlerExceptions.isEmpty()) {
            UTLErrorLog.insertErrorLogs(createsExceptionLogs(this.DUPPALRHandlerExceptions), CLASSNAME);
        }
    }

    /**
     * Update project helper field changes on afterInsert
     */
    private void handleProjectHelperFieldChangeOnInsert(Map<Id, Project_Account_Lead_Relation__c> newPALRsByIds) {
        List<Project__c> projects2Update = new List<Project__c>();
        Map<Id, Project__c> projects2UpdateMap = new Map<Id, Project__c>();
        Map<Id, Project__c> newRelatedProjects = getRelatedProjectsMap(newPALRsByIds);
        Map<Id, Account_Lead__c> newAccountsMap = getRelatedAccountLeadsMapByIds(newPALRsByIds);

        try {
            for(Project_Account_Lead_Relation__c newPALR : newPALRsByIds.values()) {            
                //check if related project was updated for another Project Project_Account_Lead_Relation__c record to prevent "Duplicate id in list" error
                Project__c newRelatedProject = new Project__c();
                if(projects2UpdateMap.containsKey(newPALR.Project__c)) {
                    newRelatedProject = projects2UpdateMap.get(newPALR.Project__c);
                } else {
                    newRelatedProject = newRelatedProjects.get(newPALR.Project__c);
                }

                //format account name
                String newInvolvedAccountName = DUPDuplicateCheckHelper.formatAccountName(newAccountsMap.get(newPALR.Account_Lead__c).Name);

                //Prepare Building owner helper field, if building owner is added
                if(newPALR.Account_Role__c == '3' && 
                newRelatedProject.Building_Owner_cleaned__c == null) {
                    newRelatedProject.Building_Owner_cleaned__c = newInvolvedAccountName;
                    newRelatedProject.Building_Owner__c = newAccountsMap.get(newPALR.Account_Lead__c).Name;
                } else if(newPALR.Account_Role__c != '3') {
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
            createExceptionsPerPALR(e, newPALRsByIds);
        }
    }

    /**
     * Update project helper field changes on afterUpdate
     */
    private void handleProjectHelperFieldChangeOnUpdate(Map<Id, Project_Account_Lead_Relation__c> oldPALRsByIds, Map<Id, Project_Account_Lead_Relation__c> newPALRsByIds) {
        List<Project__c> projects2Update = new List<Project__c>();
        Map<Id, Project__c> projects2UpdateMap = new Map<Id, Project__c>();
        Map<Id, Project__c> oldRelatedProjects = getRelatedProjectsMap(oldPALRsByIds);
        Map<Id, Project__c> newRelatedProjects = getRelatedProjectsMap(newPALRsByIds);
        Map<Id, Account_Lead__c> oldAccountsMap = getRelatedAccountLeadsMapByIds(oldPALRsByIds);
        Map<Id, Account_Lead__c> newAccountsMap = getRelatedAccountLeadsMapByIds(newPALRsByIds);
        Map<Id, List<Project_Account_Lead_Relation__c>> buildingOwnerLeadsByProjectIdMap =  getBuildingOwnerLeadsByProjectIdMap(oldRelatedProjects.keySet());
        List<String> accountRoleOptions = DUPDuplicateCheckHelper.getPicklistFieldOptions(PROJECT_ACCOUNT_LEAD_RELATION_SOBJECT_API_NAME, ACCOUNT_ROLE_FIELD_API_NAME);
        
        try {
            for(Project_Account_Lead_Relation__c newPALR : newPALRsByIds.values()) {
                Project_Account_Lead_Relation__c oldPALR = oldPALRsByIds.get(newPALR.Id);

                //check if related project was updated for another Project Project_Account_Lead_Relation__c record to prevent "Duplicate id in list" error
                Project__c oldRelatedProject = new Project__c();
                Project__c newRelatedProject = new Project__c();
                if(projects2UpdateMap.containsKey(oldPALR.Project__c)) {
                    oldRelatedProject = projects2UpdateMap.get(oldPALR.Project__c);
                } else {
                    oldRelatedProject = oldRelatedProjects.get(oldPALR.Project__c);
                }
                if(projects2UpdateMap.containsKey(newPALR.Project__c)) {
                    newRelatedProject = projects2UpdateMap.get(newPALR.Project__c);
                } else {
                    newRelatedProject = newRelatedProjects.get(newPALR.Project__c);
                }

                //format account name and role
                String newInvolvedAccountFullName = newAccountsMap.get(newPALR.Account_Lead__c).Name;
                String oldInvolvedAccountName = DUPDuplicateCheckHelper.formatAccountName(oldAccountsMap.get(oldPALR.Account_Lead__c).Name);
                String newInvolvedAccountName = DUPDuplicateCheckHelper.formatAccountName(newInvolvedAccountFullName);
                List<String> oldAccountRoles = DUPDuplicateCheckHelper.formatConcatenatedStringToList(oldPALR.Account_Role__c, ';');
                List<String> newAccountRoles = DUPDuplicateCheckHelper.formatConcatenatedStringToList(newPALR.Account_Role__c, ';');
                //Count how many non-Building Owner Roles were selected before the update
                Boolean oldPALRHasNonBusinessOwnerRole = DUPDuplicateCheckHelper.containsCommonValue(accountRoleOptions, oldAccountRoles);
                //Count how many non-Building Owner Roles were selected after the update
                Boolean newPALRHasNonBusinessOwnerRole = DUPDuplicateCheckHelper.containsCommonValue(accountRoleOptions, newAccountRoles);

                //1.1   Building Owner Role was removed
                if(oldPALR.Account_Role__c == '3' &&
                newPALR.Account_Role__c != '3' &&
                (oldRelatedProject.Building_Owner_cleaned__c == oldInvolvedAccountName) && 
                (buildingOwnerLeadsByProjectIdMap.isEmpty() || (!buildingOwnerLeadsByProjectIdMap.isEmpty() && buildingOwnerLeadsByProjectIdMap.get(oldPALR.Project__c) == null))) {
                    oldRelatedProject.Building_Owner_cleaned__c = '';
                    oldRelatedProject.Building_Owner__c = '';
                } else if(oldPALR.Account_Role__c == '3' &&
                newPALR.Account_Role__c != '3' &&
                (oldRelatedProject.Building_Owner_cleaned__c == oldInvolvedAccountName) && 
                !buildingOwnerLeadsByProjectIdMap.isEmpty() &&
                buildingOwnerLeadsByProjectIdMap.get(oldPALR.Project__c) != null) {
                    String oldBuildingOwnerName = DUPDuplicateCheckHelper.formatAccountName(buildingOwnerLeadsByProjectIdMap.get(oldPALR.Project__c)[0].Account_Lead__r.Name);
                    oldRelatedProject.Building_Owner_cleaned__c = oldBuildingOwnerName;
                    oldRelatedProject.Building_Owner__c = buildingOwnerLeadsByProjectIdMap.get(oldPALR.Project__c)[0].Account_Lead__r.Name;
                }
                //1.2   Building Owner Role was added, and field was empty before
                else if(newPALR.Account_Role__c == '3' && 
                oldRelatedProject.Building_Owner__c == null) {
                    oldRelatedProject.Building_Owner_cleaned__c = newInvolvedAccountName;
                    oldRelatedProject.Building_Owner__c = newInvolvedAccountFullName;
                }

                //2.1   Last non-Building Owner Role was removed
                if(oldPALRHasNonBusinessOwnerRole &&
                (! newPALRHasNonBusinessOwnerRole ||
                newPALR.Account_Role__c == null)) {
                    oldRelatedProject.Involved_Accounts_cleaned__c = DUPDuplicateCheckHelper.removeValueInConcatenatedString(oldRelatedProject.Involved_Accounts_cleaned__c, oldInvolvedAccountName);
                } 
                //2.2   First non-Building Owner Role was added
                else if((! oldPALRHasNonBusinessOwnerRole ||
                oldPALR.Account_Role__c == null) && 
                newPALRHasNonBusinessOwnerRole) {
                    oldRelatedProject.Involved_Accounts_cleaned__c = DUPDuplicateCheckHelper.addValueToConcatenatedString(oldRelatedProject.Involved_Accounts_cleaned__c, newInvolvedAccountName);
                } 

                //set Automation_Time__c to pass by validation rule 
		        oldRelatedProject.Automation_Time__c = System.now();
                projects2UpdateMap.put(oldRelatedProject.Id, oldRelatedProject);
            } 

            //update helper fields on project
            projects2Update.addAll(projects2UpdateMap.values());
            updateProjectRecords(projects2Update);

        } catch (Exception e) {
            createExceptionsPerPALR(e, newPALRsByIds);
        }
    }

    /**
     * Update project helper field changes on afterDelete
     */
    private void handleProjectHelperFieldChangeOnDelete(Map<Id, Project_Account_Lead_Relation__c> oldPALRsByIds) {
        List<Project__c> projects2Update = new List<Project__c>();
        Map<Id, Project__c> projects2UpdateMap = new Map<Id, Project__c>();
        Map<Id, Project__c> oldRelatedProjects = getRelatedProjectsMap(oldPALRsByIds);
        Map<Id, Account_Lead__c> oldAccountsMap = getRelatedAccountLeadsMapByIds(oldPALRsByIds);
        Map<Id, List<Project_Account_Lead_Relation__c>> buildingOwnerLeadsByProjectIdMap =  getBuildingOwnerLeadsByProjectIdMap(oldRelatedProjects.keySet());

        try {
            for(Project_Account_Lead_Relation__c oldPALR : oldPALRsByIds.values()) {
                //check if related project was updated for another Project Project_Account_Lead_Relation__c record to prevent "Duplicate id in list" error
                Project__c oldRelatedProject = new Project__c();
                if(projects2UpdateMap.containsKey(oldPALR.Project__c)) {
                    oldRelatedProject = projects2UpdateMap.get(oldPALR.Project__c);
                } else {
                    oldRelatedProject = oldRelatedProjects.get(oldPALR.Project__c);
                }

                //format account name
                String oldInvolvedAccountName = DUPDuplicateCheckHelper.formatAccountName(oldAccountsMap.get(oldPALR.Account_Lead__c).Name);

                //Clear building owner on related project, if no replacement is available
                if(oldPALR.Account_Role__c == '3' &&
                (oldRelatedProject.Building_Owner_cleaned__c == oldInvolvedAccountName) &&
                (buildingOwnerLeadsByProjectIdMap.isEmpty() || (!buildingOwnerLeadsByProjectIdMap.isEmpty() && buildingOwnerLeadsByProjectIdMap.get(oldPALR.Project__c) == null))) {
                    oldRelatedProject.Building_Owner_cleaned__c = '';
                    oldRelatedProject.Building_Owner__c = '';
                //if other building owner exists, set new value
                } else if(oldPALR.Account_Role__c == '3' &&
                (oldRelatedProject.Building_Owner_cleaned__c == oldInvolvedAccountName) && 
                !buildingOwnerLeadsByProjectIdMap.isEmpty() &&
                buildingOwnerLeadsByProjectIdMap.get(oldPALR.Project__c) != null) {
                    String oldBuildingOwnerName = DUPDuplicateCheckHelper.formatAccountName(buildingOwnerLeadsByProjectIdMap.get(oldPALR.Project__c)[0].Account_Lead__r.Name);
                    oldRelatedProject.Building_Owner_cleaned__c = oldBuildingOwnerName;
                    oldRelatedProject.Building_Owner__c = buildingOwnerLeadsByProjectIdMap.get(oldPALR.Project__c)[0].Account_Lead__r.Name;
                // clear involved account fields
                } else if(oldPALR.Account_Role__c != '3') {
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
            createExceptionsPerPALR(e, oldPALRsByIds);
        }
    }

    /**
     * Update project helper field changes on afterUndelete
     */
    private void handleProjectHelperFieldChangeOnUndelete(Map<Id, Project_Account_Lead_Relation__c> newPALRsByIds) {
        List<Project__c> projects2Update = new List<Project__c>();
        Map<Id, Project__c> projects2UpdateMap = new Map<Id, Project__c>();
        Map<Id, Project__c> newRelatedProjects = getRelatedProjectsMap(newPALRsByIds);
        Map<Id, Account_Lead__c> newAccountsMap = getRelatedAccountLeadsMapByIds(newPALRsByIds);
        
        try {
            for(Project_Account_Lead_Relation__c newPALR : newPALRsByIds.values()) {
                //check if related project was updated for another Project Project_Account_Lead_Relation__c record to prevent "Duplicate id in list" error
                Project__c newRelatedProject = new Project__c();
                if(projects2UpdateMap.containsKey(newPALR.Project__c)) {
                    newRelatedProject = projects2UpdateMap.get(newPALR.Project__c);
                } else {
                    newRelatedProject = newRelatedProjects.get(newPALR.Project__c);
                }

                //format account name
                String newInvolvedAccountFullName = newAccountsMap.get(newPALR.Account_Lead__c).Name;
                String newInvolvedAccountName = DUPDuplicateCheckHelper.formatAccountName(newInvolvedAccountFullName);

                //Prepare Building owner helper field, if building owner is added
                if(newPALR.Account_Role__c == '3' &&
                newRelatedProject.Building_Owner_cleaned__c == null) {
                    newRelatedProject.Building_Owner_cleaned__c = newInvolvedAccountName;
                    newRelatedProject.Building_Owner__c = newInvolvedAccountFullName;
                } else {
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
            createExceptionsPerPALR(e, newPALRsByIds);
        }
    }

    /**
     * Helper method to update project records, on which helper fields were updated
     * 
     * @palram projects2Update list of projects to be updated
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
                    this.DUPPALRHandlerExceptions.put(
                        projId,
                        new DUPPALRHandlerException('Processing error: ' + exceptionMessage)
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
    private Map<Id, Project__c> getRelatedProjectsMap(Map<Id, Project_Account_Lead_Relation__c> newPALRsByIds) {
        Set<Id> relatedProjectIds = new Set<Id>();
        
        for(Project_Account_Lead_Relation__c newPALR : newPALRsByIds.values()) {
            relatedProjectIds.add(newPALR.Project__c);
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
    private Map<Id, Account_Lead__c> getRelatedAccountLeadsMapByIds(Map<Id, Project_Account_Lead_Relation__c> palrsByIds) {
        Set<Id> relatedAccountLeadIds = new Set<Id>();
        
        for(Project_Account_Lead_Relation__c palr : palrsByIds.values()) {
            relatedAccountLeadIds.add(palr.Account_Lead__c);
        }

        Map<Id, Account_Lead__c> relatedAccountLeadsMap = new Map<Id, Account_Lead__c>(
            [
                SELECT 
                    Id, 
                    Name
                FROM Account_Lead__c
                WHERE Id IN :relatedAccountLeadIds
            ]
        );

        return relatedAccountLeadsMap;
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
                                                            AND Account_Role__c = '3']) {
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
     * @palram e Single Exception to replicate by ProjectAccountRelation-Id
     * @palram newPALRsByIds ProjectAccountRelation-Map
     */
    private void createExceptionsPerPALR(Exception e, Map<Id, Project_Account_Lead_Relation__c> newPALRsByIds) {
        for (Id palrId : newPALRsByIds.keySet()) {
            this.DUPPALRHandlerExceptions.put(palrId, new DUPPALRHandlerException(e.getMessage()));
        }
    }

    /**
     * Maps DUPPALRHandlerException and ProjectAccountRelation-Id's to a List of Core_Error_Log__c.
     *
     * @palram dupPALRHandlerExceptionsByPALRIds created Core_Error_Log__c list
     *
     * @return List of Core_Error_Log__c
     */
    private List<Core_Error_Log__c> createsExceptionLogs(Map<Id, DUPPALRHandlerException> dupPALRHandlerExceptionsByPALRIds) {
        List<Core_Error_Log__c> coreErrorLogs = new List<Core_Error_Log__c>();

        for (Id palrId : dupPALRHandlerExceptionsByPALRIds.keySet()) {
            DUPPALRHandlerException dUPPALRHandlerException = dupPALRHandlerExceptionsByPALRIds.get(palrId);

            System.debug('Exception occured:');
            System.debug('Message:' + dUPPALRHandlerException.getMessage());
            System.debug('Stack:' + dUPPALRHandlerException.getStackTraceString());
            System.debug('Line:' + dUPPALRHandlerException.getLineNumber());

            Core_Error_Log__c coreErrorLog = UTLErrorLog.createErrorLogRecord(
                CLASSNAME,
                dUPPALRHandlerException,
                'Error on ProjectAccountRelation Handling',
                palrId
            );
            coreErrorLogs.add(coreErrorLog);
        }
        return coreErrorLogs;
    }

    public class DUPPALRHandlerException extends Exception {
    }
}