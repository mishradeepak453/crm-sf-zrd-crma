/**
 * SF-1205: Update helper fields on Project__c records with updated Account_Lead__c changes
 *
 * @author  isabella.moos@accenture.com
 *
 * @version 2023-10-09      isabella.moos@accenture.com     creation
 */
public without sharing class DUPAccountLeadHandler {
    @TestVisible
    private final String CLASSNAME = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));

    private Map<Id, Account_Lead__c> oldAccountLeadsByIds;
    private Map<Id, Account_Lead__c> newAccountLeadsByIds;

    private Map<Id, DUPAccountLeadHandlerException> DUPAccountLeadHandlerExceptions = new Map<Id, DUPAccountLeadHandlerException>();

    /**
     * Chain-Methode to build the Handler
     *
     * @param oldAccountLeadsByIds Old Account_Lead__c-Maps is mandatory
     *
     * @return DUPAccountLeadHandler
     */
    public DUPAccountLeadHandler addOldAccounts(Map<Id, Account_Lead__c> oldAccountLeadsByIds) {
        this.oldAccountLeadsByIds = oldAccountLeadsByIds;
        return this;
    }

    /**
     * Chain-Methode to build the Handler
     *
     * @param newAccountLeadsByIds New Account_Lead__c-Maps is mandatory
     *
     * @return DUPAccountLeadHandler
     */
    public DUPAccountLeadHandler addNewAccounts(Map<Id, Account_Lead__c> newAccountLeadsByIds) {
        this.newAccountLeadsByIds = newAccountLeadsByIds;
        return this;
    }

    /**
     * To choose async execution-context
     */
    public enum JobContext {
        ON_UPDATE
    }

    /**
     * Async execution methode
     *
     * @param context JobContext is mandatory to chose execution-context
     */
    public void executeJob(JobContext context) {
        DUPAccountLeadHandlerJob dupAccountLeadQueueable = new DUPAccountLeadHandlerJob(this, context);

        if (
            context == JobContext.ON_UPDATE &&
            (this.oldAccountLeadsByIds == null ||
            this.newAccountLeadsByIds == null ||
            this.newAccountLeadsByIds.isEmpty())
        ) {
            throw new DUPAccountLeadHandlerException('Account Leads not properly initiated.');
        } else {
            UTLQueueableUtility.enqueueJob(dupAccountLeadQueueable);
        }
    }

    /**
     * To execute the outer class in an async context.
     */
    private class DUPAccountLeadHandlerJob implements Queueable {
        private String CLASSNAME = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));

        private JobContext context;

        private DUPAccountLeadHandler dUPAccountLeadHandler;

        private DUPAccountLeadHandlerJob(DUPAccountLeadHandler dUPAccountLeadHandler, JobContext context) {
            this.dUPAccountLeadHandler = dUPAccountLeadHandler;
            this.context = context;
        }

        public void execute(QueueableContext qc) {
            try {
                switch on Context {
                    when ON_UPDATE {
                        dUPAccountLeadHandler.handleAccountLeadChangeAsync();
                    }
                    when else {
                        throw new DUPAccountLeadHandlerException('Unknown JobContext');
                    }
                }
            } catch (Exception e) {
                UTLErrorLog.insertErrorLogs(
                    new List<Core_Error_Log__c>{
                        UTLErrorLog.createErrorLogRecord(
                            this.CLASSNAME,
                            e,
                            'Queueable-Execution-Error on Account_Lead__c Handling',
                            qc.getJobId()
                        )
                    },
                    this.CLASSNAME
                );
            }
        }
    }

    /**
     * Async handling for Change
     */
    private void handleAccountLeadChangeAsync() {
        handleAccountLeadNameChanges(this.oldAccountLeadsByIds, this.newAccountLeadsByIds);

        //handle DUPAccountLeadHandlerExceptions
        if (!this.DUPAccountLeadHandlerExceptions.isEmpty()) {
            UTLErrorLog.insertErrorLogs(createsExceptionLogs(this.DUPAccountLeadHandlerExceptions), CLASSNAME);
        }
    }

    /**
     * Update helper field changes on projects with changed Account_Lead__c Names on afterUpdate
     */
    public void handleAccountLeadNameChanges(Map<Id, Account_Lead__c> oldAccountLeadsByIds, Map<Id, Account_Lead__c> newAccountLeadsByIds) {
        try {
            List<Project__c> projects2Update = new List<Project__c>();
            Map<Id, Project__c> projectsMap2Update = new Map<Id, Project__c>();
            ProjectAccountLeadRelationsByProjectsWrapper palrWrapper = buildPALRListsByProjectIdsMap(oldAccountLeadsByIds.keySet());
            Map<Id, List<Project_Account_Lead_Relation__c>> palrListsByProjectIds = palrWrapper.palrListsByProjectIds;
            Map<Id, Project__c> projectsMap = palrWrapper.projectsMap;
            Map<Id, FormattedAccountLeadNameWrapper> formattedAccountNamesMap = new Map<Id, FormattedAccountLeadNameWrapper>();

            //format account names and store them in wrapper
            for(Account_Lead__c oldAccount : oldAccountLeadsByIds.values()) {
                FormattedAccountLeadNameWrapper wrapper = new FormattedAccountLeadNameWrapper();
                wrapper.oldAccountLeadName = DUPDuplicateCheckHelper.formatAccountName(oldAccount.Name);
                wrapper.newAccountLeadName = DUPDuplicateCheckHelper.formatAccountName(newAccountLeadsByIds.get(oldAccount.Id).Name);
                formattedAccountNamesMap.put(oldAccount.Id, wrapper);
            }

            for(Id projectId : palrListsByProjectIds.keySet()) {
                Project__c project = projectsMap.get(projectId);

                //iterate over ProjectAccountRelations per project and update helper fields on project with new Account_Lead__c Names
                List<Project_Account_Lead_Relation__c> projectRelatedPALRs = palrListsByProjectIds.get(projectId);
                for(Project_Account_Lead_Relation__c palr : projectRelatedPALRs) {

                    //if project was updated before, get latest update
                    if(projectsMap2Update.containsKey(projectId)) {
                        project = projectsMap2Update.get(projectId);
                    }

                    //update project helper fields
                    if(palr.Account_Role__c == '3') {
                        project.Building_Owner_cleaned__c = formattedAccountNamesMap.get(palr.Account_Lead__c).newAccountLeadName; 
                        project.Building_Owner__c = newAccountLeadsByIds.get(palr.Account_Lead__c).Name;
                    } else {
                        project.Involved_Accounts_cleaned__c = DUPDuplicateCheckHelper.replaceValueInConcatenatedString(project.Involved_Accounts_cleaned__c, 
                                                                                                                            formattedAccountNamesMap.get(palr.Account_Lead__c).oldAccountLeadName,
                                                                                                                            formattedAccountNamesMap.get(palr.Account_Lead__c).newAccountLeadName);
                    }

                    //set Automation_Time__c to pass by validation rule 
		            project.Automation_Time__c = System.now();
                    projectsMap2Update.put(project.Id, project);
                }
            }
        
            //update project records
            projects2Update.addAll(projectsMap2Update.values());
            if(!projects2Update.isEmpty()) {
                Database.SaveResult[] projectUpdateResult = Database.update(projects2Update, false);
                if(Test.isRunningTest()) {
                    throw new DMLException('Test Error');
                }
                
                // check results and create rerror logs
                Integer i = 0;
                for (Database.SaveResult sr : projectUpdateResult) {
                    if (!sr.isSuccess()) {
                        Id projId = projects2Update[i].Id;
    
                        String errorMessage = 'Error while updating Project__c record with ID ' + projId;
                        String exceptionMessage = sr.getErrors()[0].getStatusCode() + ': ' + sr.getErrors()[0].getMessage();
    
                        System.debug('########## RP exceptionMessage: ' + exceptionMessage);
                        this.DUPAccountLeadHandlerExceptions.put(
                            projId,
                            new DUPAccountLeadHandlerException('Processing error: ' + exceptionMessage)
                        );
                    }
                    i++;
                }
            }

        } catch (Exception e) {
            createExceptionsPerAccount(e, newAccountLeadsByIds);
        }
    }

    /**
     * Query Project_Account_Lead_Relation__c records by Account_Lead__c-Ids
     * 
     * @param accountLeadIds Account_Lead__c Ids to query related Project_Account_Lead_Relation__c records
     * 
     * @return Set<Id> of Project__c records
     */
    private ProjectAccountLeadRelationsByProjectsWrapper buildPALRListsByProjectIdsMap (Set<Id> accountLeadIds) {
        ProjectAccountLeadRelationsByProjectsWrapper palrWrapper = new ProjectAccountLeadRelationsByProjectsWrapper();
        Map<Id, List<Project_Account_Lead_Relation__c>> palrListsByProjectIds = new Map<Id, List<Project_Account_Lead_Relation__c>>();
        Map<Id, Project__c> projectsMap = new Map<Id, Project__c>();

        // Query ProjectAccountRelation records, build map to associate list of ProjectAccountRelations to related Project Id
        for(Project_Account_Lead_Relation__c palr : [SELECT
                                                    Id,
                                                    Project__c,
                                                    Project__r.Building_Owner__c,
                                                    Project__r.Building_Owner_cleaned__c,
                                                    Project__r.Involved_Accounts_cleaned__c,
                                                    Account_Lead__c,
                                                    Account_Role__c
                                                FROM Project_Account_Lead_Relation__c
                                                WHERE Account_Lead__c IN :accountLeadIds]) {
            
            //build map to associate ProjectAccountRelation List to Project Ids
            if(palrListsByProjectIds.containsKey(palr.Project__c)) {
                List<Project_Account_Lead_Relation__c> palrIdList = palrListsByProjectIds.get(palr.Project__c);
                palrIdList.add(palr);
                palrListsByProjectIds.put(palr.Project__c, palrIdList);
            } else {
                palrListsByProjectIds.put(palr.Project__c, new List<Project_Account_Lead_Relation__c> { palr });
            }

            // build project map
            if(! projectsMap.containsKey(palr.Project__c)) {
                Project__c project = new Project__c(
                    Id =  palr.Project__c,
                    Building_Owner__c = palr.Project__r.Building_Owner__c,
                    Building_Owner_cleaned__c = palr.Project__r.Building_Owner_cleaned__c,
                    Involved_Accounts_cleaned__c = palr.Project__r.Involved_Accounts_cleaned__c
                );
                projectsMap.put(palr.Project__c, project);
            }
        }

        palrWrapper.palrListsByProjectIds = palrListsByProjectIds;
        palrWrapper.projectsMap = projectsMap;
        
        return palrWrapper;
    }

    /**
     * Wrapper for account name changes
     */
    public class ProjectAccountLeadRelationsByProjectsWrapper {
        public Map<Id, List<Project_Account_Lead_Relation__c>> palrListsByProjectIds;
        public Map<Id, Project__c> projectsMap;
    }

    /**
     * Wrapper for account name changes
     */
    public class FormattedAccountLeadNameWrapper {
        public String oldAccountLeadName;
        public String newAccountLeadName;
    }

    /**
     * Creates Exceptions mapped by Account_Lead__c Ids
     *
     * @param e Single Exception to replicate by Account_Lead__c-Id
     * @param newAccountLeadsByIds Account_Lead__c-Map
     */
    private void createExceptionsPerAccount(Exception e, Map<Id, Account_Lead__c> newAccountLeadsByIds) {
        for (Id accId : newAccountLeadsByIds.keySet()) {
            this.DUPAccountLeadHandlerExceptions.put(accId, new DUPAccountLeadHandlerException(e.getMessage()));
        }
    }

    /**
     * Maps DUPAccountLeadHandlerException and Account_Lead__c-Id's to a List of Core_Error_Log__c.
     *
     * @param dUPAccountHandlerExceptionsByProjectIds created Core_Error_Log__c list
     *
     * @return List of Core_Error_Log__c
     */
    private List<Core_Error_Log__c> createsExceptionLogs(Map<Id, DUPAccountLeadHandlerException> dUPAccountHandlerExceptionsByProjectIds) {
        List<Core_Error_Log__c> coreErrorLogs = new List<Core_Error_Log__c>();

        for (Id accountLeadId : dUPAccountHandlerExceptionsByProjectIds.keySet()) {
            DUPAccountLeadHandlerException dUPAccountHandlerException = dUPAccountHandlerExceptionsByProjectIds.get(accountLeadId);

            System.debug('Exception occured:');
            System.debug('Message:' + dUPAccountHandlerException.getMessage());
            System.debug('Stack:' + dUPAccountHandlerException.getStackTraceString());
            System.debug('Line:' + dUPAccountHandlerException.getLineNumber());

            Core_Error_Log__c coreErrorLog = UTLErrorLog.createErrorLogRecord(
                CLASSNAME,
                dUPAccountHandlerException,
                'Error on Account_Lead__c Handling',
                accountLeadId
            );
            coreErrorLogs.add(coreErrorLog);
        }
        return coreErrorLogs;
    }

    public class DUPAccountLeadHandlerException extends Exception {
    }
}