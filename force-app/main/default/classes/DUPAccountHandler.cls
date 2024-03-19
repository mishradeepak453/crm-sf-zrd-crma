/**
 * SF-1205: Update helper fields on Project__c records with updated Account changes
 *
 * @author  isabella.moos@accenture.com
 *
 * @version 2023-10-09      isabella.moos@accenture.com     creation
 */
public without sharing class DUPAccountHandler {
    @TestVisible
    private String CLASSNAME = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));
    private String PROJECT_ACCOUNT_RELATION_SOBJECT_API_NAME = 'Project_Account_Relation__c';
    private String ACCOUNT_ROLE_FIELD_API_NAME = 'Account_Role__c';

    private Map<Id, Account> oldAccountsByIds;
    private Map<Id, Account> newAccountsByIds;

    private Map<Id, DUPAccountHandlerException> DUPAccountHandlerExceptions = new Map<Id, DUPAccountHandlerException>();

    /**
     * Chain-Methode to build the Handler
     *
     * @param oldAccountsByIds Old Account-Maps is mandatory
     *
     * @return DUPAccountHandler
     */
    public DUPAccountHandler addOldAccounts(Map<Id, Account> oldAccountsByIds) {
        this.oldAccountsByIds = oldAccountsByIds;
        return this;
    }

    /**
     * Chain-Methode to build the Handler
     *
     * @param newAccountsByIds New Account-Maps is mandatory
     *
     * @return DUPAccountHandler
     */
    public DUPAccountHandler addNewAccounts(Map<Id, Account> newAccountsByIds) {
        this.newAccountsByIds = newAccountsByIds;
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
        DUPAccountHandlerJob dupAccQueueable = new DUPAccountHandlerJob(this, context);

        if (
            context == JobContext.ON_UPDATE &&
            (this.oldAccountsByIds == null ||
            this.newAccountsByIds == null ||
            this.newAccountsByIds.isEmpty())
        ) {
            throw new DUPAccountHandlerException('Accounts not properly initiated.');
        } else {
            UTLQueueableUtility.enqueueJob(dupAccQueueable);
        }
    }

    /**
     * To execute the outer class in an async context.
     */
    private class DUPAccountHandlerJob implements Queueable {
        private String CLASSNAME = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));

        private JobContext context;

        private DUPAccountHandler dUPAccountHandler;

        private DUPAccountHandlerJob(DUPAccountHandler dUPAccountHandler, JobContext context) {
            this.dUPAccountHandler = dUPAccountHandler;
            this.context = context;
        }

        public void execute(QueueableContext qc) {
            try {
                switch on Context {
                    when ON_UPDATE {
                        dUPAccountHandler.handleAccountChangeAsync();
                    }
                    when else {
                        throw new DUPAccountHandlerException('Unknown JobContext');
                    }
                }
            } catch (Exception e) {
                UTLErrorLog.insertErrorLogs(
                    new List<Core_Error_Log__c>{
                        UTLErrorLog.createErrorLogRecord(
                            this.CLASSNAME,
                            e,
                            'Queueable-Execution-Error on Account Handling',
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
    private void handleAccountChangeAsync() {
        handleAccountNameChanges(this.oldAccountsByIds, this.newAccountsByIds);

        //handle DUPAccountHandlerExceptions
        if (!this.DUPAccountHandlerExceptions.isEmpty()) {
            UTLErrorLog.insertErrorLogs(createsExceptionLogs(this.DUPAccountHandlerExceptions), CLASSNAME);
        }
    }

    /**
     * Update helper field changes on projects with changed Account Names on afterUpdate
     */
    public void handleAccountNameChanges(Map<Id, Account> oldAccountsByIds, Map<Id, Account> newAccountsByIds) {
        try {
            List<Project__c> projects2Update = new List<Project__c>();
            Map<Id, Project__c> projectsMap2Update = new Map<Id, Project__c>();
            ProjectAccountRelationsByProjectsWrapper parWrapper = buildPARListsByProjectIdsMap(oldAccountsByIds.keySet());
            Map<Id, List<Project_Account_Relation__c>> parListsByProjectIds = parWrapper.parListsByProjectIds;
            Map<Id, Project__c> projectsMap = parWrapper.projectsMap;
            Map<Id, FormattedAccountNameWrapper> formattedAccountNamesMap = new Map<Id, FormattedAccountNameWrapper>();
            List<String> accountRoleOptions = DUPDuplicateCheckHelper.getPicklistFieldOptions(PROJECT_ACCOUNT_RELATION_SOBJECT_API_NAME, ACCOUNT_ROLE_FIELD_API_NAME);

            //format account names and store them in wrapper
            for(Account oldAccount : oldAccountsByIds.values()) {
                FormattedAccountNameWrapper wrapper = new FormattedAccountNameWrapper();
                wrapper.oldAccountName = DUPDuplicateCheckHelper.formatAccountName(oldAccount.Name);
                wrapper.newAccountName = DUPDuplicateCheckHelper.formatAccountName(newAccountsByIds.get(oldAccount.Id).Name);
                formattedAccountNamesMap.put(oldAccount.Id, wrapper);
            }

            for(Id projectId : parListsByProjectIds.keySet()) {
                Project__c project = projectsMap.get(projectId);

                //iterate over ProjectAccountRelations per project and update helper fields on project with new Account Names
                List<Project_Account_Relation__c> projectRelatedPARs = parListsByProjectIds.get(projectId);
                List<String> accountRoles = new List<String>();
                for(Project_Account_Relation__c par : projectRelatedPARs) {

                    //if project was updated before, get latest update
                    if(projectsMap2Update.containsKey(projectId)) {
                        project = projectsMap2Update.get(projectId);
                    }

                    //init account roles
                    if(accountRoles.isEmpty()) {
                        accountRoles = DUPDuplicateCheckHelper.formatConcatenatedStringToList(par.Account_Role__c, ';');
                    }

                    //update project helper fields
                    if(par.Account_Role__c.contains('3')) {
                        project.Building_Owner_cleaned__c = formattedAccountNamesMap.get(par.Account__c).newAccountName; 
                        project.Building_Owner__c = newAccountsByIds.get(par.Account__c).Name;
                    } 
                    if(DUPDuplicateCheckHelper.containsCommonValue(accountRoleOptions, accountRoles)) {
                        project.Involved_Accounts_cleaned__c = DUPDuplicateCheckHelper.replaceValueInConcatenatedString(project.Involved_Accounts_cleaned__c, 
                                                                                                                            formattedAccountNamesMap.get(par.Account__c).oldAccountName,
                                                                                                                            formattedAccountNamesMap.get(par.Account__c).newAccountName);
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
                        this.DUPAccountHandlerExceptions.put(
                            projId,
                            new DUPAccountHandlerException('Processing error: ' + exceptionMessage)
                        );
                    }
                    i++;
                }
            }

        } catch (Exception e) {
            createExceptionsPerAccount(e, newAccountsByIds);
        }
    }

    /**
     * Query Project_Account_Relation__c records by Account-Ids
     * 
     * @param accountIds Account Ids to query related Project_Account_Relation__c records
     * 
     * @return Set<Id> of Project__c records
     */
    private ProjectAccountRelationsByProjectsWrapper buildPARListsByProjectIdsMap (Set<Id> accountIds) {
        ProjectAccountRelationsByProjectsWrapper parWrapper = new ProjectAccountRelationsByProjectsWrapper();
        Map<Id, List<Project_Account_Relation__c>> parListsByProjectIds = new Map<Id, List<Project_Account_Relation__c>>();
        Map<Id, Project__c> projectsMap = new Map<Id, Project__c>();

        // Query ProjectAccountRelation records, build map to associate list of ProjectAccountRelations to related Project Id
        for(Project_Account_Relation__c par : [SELECT
                                                    Id,
                                                    Project__c,
                                                    Project__r.Building_Owner__c,
                                                    Project__r.Building_Owner_cleaned__c,
                                                    Project__r.Involved_Accounts_cleaned__c,
                                                    Account__c,
                                                    Account_Role__c
                                                FROM Project_Account_Relation__c
                                                WHERE Account__c IN :accountIds]) {
            
            //build map to associate ProjectAccountRelation List to Project Ids
            if(parListsByProjectIds.containsKey(par.Project__c)) {
                List<Project_Account_Relation__c> parIdList = parListsByProjectIds.get(par.Project__c);
                parIdList.add(par);
                parListsByProjectIds.put(par.Project__c, parIdList);
            } else {
                parListsByProjectIds.put(par.Project__c, new List<Project_Account_Relation__c> { par });
            }

            // build project map
            if(! projectsMap.containsKey(par.Project__c)) {
                Project__c project = new Project__c(
                    Id =  par.Project__c,
                    Building_Owner__c = par.Project__r.Building_Owner__c,
                    Building_Owner_cleaned__c = par.Project__r.Building_Owner_cleaned__c,
                    Involved_Accounts_cleaned__c = par.Project__r.Involved_Accounts_cleaned__c
                );
                projectsMap.put(par.Project__c, project);
            }
        }

        parWrapper.parListsByProjectIds = parListsByProjectIds;
        parWrapper.projectsMap = projectsMap;
        
        return parWrapper;
    }

    /**
     * Wrapper for account name changes
     */
    public class ProjectAccountRelationsByProjectsWrapper {
        public Map<Id, List<Project_Account_Relation__c>> parListsByProjectIds;
        public Map<Id, Project__c> projectsMap;
    }

    /**
     * Wrapper for account name changes
     */
    public class FormattedAccountNameWrapper {
        public String oldAccountName;
        public String newAccountName;
    }

    /**
     * Creates Exceptions mapped by Account Ids
     *
     * @param e Single Exception to replicate by Account-Id
     * @param newAccountsByIds Account-Map
     */
    private void createExceptionsPerAccount(Exception e, Map<Id, Account> newAccountsByIds) {
        for (Id accId : newAccountsByIds.keySet()) {
            this.DUPAccountHandlerExceptions.put(accId, new DUPAccountHandlerException(e.getMessage()));
        }
    }

    /**
     * Maps DUPAccountHandlerException and Account-Id's to a List of Core_Error_Log__c.
     *
     * @param dUPAccountHandlerExceptionsByProjectIds created Core_Error_Log__c list
     *
     * @return List of Core_Error_Log__c
     */
    private List<Core_Error_Log__c> createsExceptionLogs(Map<Id, DUPAccountHandlerException> dUPAccountHandlerExceptionsByProjectIds) {
        List<Core_Error_Log__c> coreErrorLogs = new List<Core_Error_Log__c>();

        for (Id accId : dUPAccountHandlerExceptionsByProjectIds.keySet()) {
            DUPAccountHandlerException dUPAccountHandlerException = dUPAccountHandlerExceptionsByProjectIds.get(accId);

            System.debug('Exception occured:');
            System.debug('Message:' + dUPAccountHandlerException.getMessage());
            System.debug('Stack:' + dUPAccountHandlerException.getStackTraceString());
            System.debug('Line:' + dUPAccountHandlerException.getLineNumber());

            Core_Error_Log__c coreErrorLog = UTLErrorLog.createErrorLogRecord(
                CLASSNAME,
                dUPAccountHandlerException,
                'Error on Account Handling',
                accId
            );
            coreErrorLogs.add(coreErrorLog);
        }
        return coreErrorLogs;
    }

    public class DUPAccountHandlerException extends Exception {
    }
}