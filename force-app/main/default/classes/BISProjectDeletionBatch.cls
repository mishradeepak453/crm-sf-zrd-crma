/**
 * SF-1014:  job to delete Project__c records from BIS (ESB).
 * 
 * @author  miriam.ida.tyroller@accenture.com
 * 
 * @version 2023-07-31  miriam.ida.tyroller       creation
 */

public with sharing class BISProjectDeletionBatch implements Database.Batchable<sObject>, Database.Stateful {

    public static final String CLASSNAME = 'BISProjectDeletionBatch';
    public String query;
    public static Integer defaultBatchSize = 350;

    // statistical values
    private Statistics stats;

    // the list of errors handled during execution 
    private List<Core_Error_Log__c> errorLogs;

    public BISProjectDeletionBatch() {
        this.stats = new Statistics();
        this.errorLogs = new List<Core_Error_Log__c>();
    }

    /**
     * The start method is called at the beginning of the batch Apex job.
     * 
     * This method returns the Database.QueryLocator that contains the projetcs records where the source system 
     * is BIS and the construction end is already exceeded, which will then be checked if they should be deleted. 
     * 
     * @param bc    Database.BatchableContext
     * 
     * @return Database.QueryLocator for Project__c records
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('########## RP BISProjectDeletionBatch: start');

        Date todayDate = Date.today();

        if (this.query == null) {
            this.query = 'SELECT Id FROM Project__c WHERE Core_Source_System__c = \'BIS\' AND Project_Construction_End__c <= : todayDate';
        }

        return Database.getQueryLocator(this.query);
    }

    /**
     * The execute method is called for each batch of projects records passed to the method and decides
     * by a logic which BIS projects should be deleted and which updated to status !active
     * 
     * @param bc    Database.BatchableContext
     * @param scope List of Project__c records to be processed
     */
    public void execute(Database.BatchableContext bc, List<Project__c> scope) {
        Integer infobauMonthLimit = (Integer) BIS_Project_Import_Config__c.getOrgDefaults().Deletion_Infobau_Month_Limit__c;
        Integer ibauMonthLimit = (Integer) BIS_Project_Import_Config__c.getOrgDefaults().Deletion_Ibau_Month_Limit__c;

        Date infoBauLimit = Date.today().addMonths(-infobauMonthLimit);
        Date iBauLimit = Date.today().addMonths(-ibauMonthLimit);

        System.debug('########## RP BISProjectDeletionBatch: execute: ' + scope.size());

        try {
            List<Project__c> projectsToDelete = new List<Project__c>();
            List<Project__c> projectsToUpdate = new List<Project__c>();
            
            // query projects and related accounts, contacts, opportunities, quotes, orders, tasks and events
            List<Project__c> projList = [
                SELECT 
                Id, 
                Project_Construction_Progress__c,
                Sales_Excellence_is_Owner__c,
                Exact_Source__c, 
                Project_Construction_End__c, 
                (SELECT Id, Project__c 
                        FROM Project_Account_Relations__r LIMIT 1), 
                (SELECT Id, Project__c 
                        FROM Project_Contact_Relations__r LIMIT 1), 
                (SELECT Id, Project__c 
                        FROM Opportunities__r LIMIT 1),
                (SELECT Id, Project__c 
                        FROM Quotes_Rental__r LIMIT 1),
                (SELECT Id, Project__c 
                        FROM Orders__r LIMIT 1), 
                (SELECT Id, WhatId 
                        FROM Tasks LIMIT 1), 
                (SELECT Id, WhatId 
                        FROM Events LIMIT 1)
                FROM Project__c 
                WHERE Id IN :scope];

            this.stats.projectCount += projList.size();

            for (Project__c proj : projList) {
                //only deactivate / delete ibau projects with the progress 7 -> Shortly before Completion / Completion 
                if(proj.Exact_Source__c == 'iBau' && proj.Project_Construction_Progress__c == '7'){
                    //only delete projects with no related accounts, contacts, opportunities, quotes, orders, tasks and events
                    if(
                            proj.Project_Account_Relations__r.size() == 0 &&
                            proj.Project_Contact_Relations__r.size() == 0 &&
                            proj.Opportunities__r.size() == 0 &&
                            proj.Quotes_Rental__r.size() == 0 &&
                            proj.Orders__r.size() == 0 &&
                            proj.Tasks.size() == 0 &&
                            proj.Events.size() == 0 ){
                                //only delete projects where the construction end is twelve months or longer ago
                                if(proj.Project_Construction_End__c <= iBauLimit ){
                                    projectsToDelete.add(proj);
                                }
                                else{
                                    //deactivate projects without related records after the construction end has passed
                                    proj.Active__c = false;
                                    projectsToUpdate.add(proj);
                                }
                                
                    }
                    else{
                        //only deactivate projects with related records after the construction end has passed 
                        //if the owner is not Sales Excellence
                        if(!proj.Sales_Excellence_is_Owner__c){
                            proj.Active__c = false;
                            projectsToUpdate.add(proj);
                        }
                    }
                }
                else if(proj.Exact_Source__c == 'infoBau'){
                    //only delete projects with no related accounts, contacts, opportunities, quotes, orders, tasks and events
                    if(
                        proj.Project_Account_Relations__r.size() == 0 &&
                        proj.Project_Contact_Relations__r.size() == 0 &&
                        proj.Opportunities__r.size() == 0 &&
                        proj.Quotes_Rental__r.size() == 0 &&
                        proj.Orders__r.size() == 0 &&
                        proj.Tasks.size() == 0 &&
                        proj.Events.size() == 0 ){
                            //only delete projects where the construction end is six months or longer ago
                            if(proj.Project_Construction_End__c <= infoBauLimit){
                                projectsToDelete.add(proj);
                            }
                            else{
                                //deactivate projects without related records after the construction end has passed
                                proj.Active__c = false;
                                projectsToUpdate.add(proj);
                            }
                    }
                    else{
                        //deactivate projects with no related records after the construction end has passed
                        proj.Active__c = false;
                        projectsToUpdate.add(proj);
                    }
                }       
            }


            System.debug(projectsToDelete.size() + ' projects will be deleted.');
            this.stats.projectsDeletedCount += projectsToDelete.size();

            //delete all projects fitting the above criteria
            if(!projectsToDelete.isEmpty()) {
                Database.DeleteResult[] projectDeleteResult = Database.delete(projectsToDelete, false);
                // check results and create error logs
                Integer i = 0;
                for (Database.DeleteResult dr : projectDeleteResult) {
                    if (!dr.isSuccess()) {
                        Id projId = projectsToDelete[i].Id;

                        String errorMessage = 'Error while deleting Project__c record with ID ' + projId;
                        String exceptionMessage = dr.getErrors()[0].getStatusCode() + ': ' + dr.getErrors()[0].getMessage();

                        System.debug('########## RP exceptionMessage: ' + exceptionMessage);
                        this.errorLogs.add(UTLErrorLog.createErrorLogRecord(CLASSNAME, new HandledException(exceptionMessage), errorMessage, projId));
                    }
                    i++;
                }
            }

            System.debug(projectsToUpdate.size() + ' projects will be updated.');
            this.stats.projectsUpdatedCount += projectsToUpdate.size();

            //deactivate all projects fitting the above criteria
            if(!projectsToUpdate.isEmpty()) {
                Database.SaveResult[] projectUpdateResult = Database.update(projectsToUpdate, false);
                // check results and create rerror logs
                Integer i = 0;
                for (Database.SaveResult sr : projectUpdateResult) {
                    if (!sr.isSuccess()) {
                        Id projId = projectsToUpdate[i].Id;

                        String errorMessage = 'Error while updating Project__c record with ID ' + projId;
                        String exceptionMessage = sr.getErrors()[0].getStatusCode() + ': ' + sr.getErrors()[0].getMessage();

                        System.debug('########## RP exceptionMessage: ' + exceptionMessage);
                        this.errorLogs.add(UTLErrorLog.createErrorLogRecord(CLASSNAME, new HandledException(exceptionMessage), errorMessage, projId));
                    }
                    i++;
                }
            }
        }
        catch (Exception e) {
            System.debug('########## RP Exception: ' + e.getMessage() + '. Line: ' + e.getLineNumber() + '. TraceString: ' + e.getStackTraceString() );
            this.errorLogs.add(UTLErrorLog.createErrorLogRecord(CLASSNAME, e, e.getMessage(), null));
        }
        
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('########## RP BISProjectDeletionBatch: finish');

        System.debug('########## RP stats: ' + this.stats);
        System.debug('########## RP projectCount: ' + this.stats.projectCount);
        System.debug('########## RP projectsDeletedCount: ' + this.stats.projectsDeletedCount);
        System.debug('########## RP projectsUpdatedCount: ' + this.stats.projectsUpdatedCount);

        UTLErrorLog.insertErrorLogs(this.errorLogs, CLASSNAME);
    }

    /**
     * Wrapper class to collect statistical values
     */
    private class Statistics {
        private Integer projectCount;
        private Integer projectsDeletedCount;
        private Integer projectsUpdatedCount;

        /**
         * Constructor
         */
        public Statistics() {
            this.projectCount = 0;
            this.projectsDeletedCount = 0;
            this.projectsUpdatedCount = 0;
        }

    }
}