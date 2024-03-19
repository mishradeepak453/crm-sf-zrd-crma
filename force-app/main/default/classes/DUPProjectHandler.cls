/**
 * SF-1205: Update helper fields on Project__c records
 *
 * @author  isabella.moos@accenture.com
 *
 * @version 2023-10-09      isabella.moos@accenture.com     creation
 */
public with sharing class DUPProjectHandler {
    @TestVisible
    private final String CLASSNAME = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));
    private Map<Id, DUPProjectHandlerException> DUPProjectHandlerExceptions = new Map<Id, DUPProjectHandlerException>();

    @TestVisible
    private Map<Id, Project__c> oldProjectsByIds;
    @TestVisible
    private Map<Id, Project__c> newProjectsByIds;
    @TestVisible
    private Boolean testError = false;

    /**
     * Chain-Method to build the Handler
     *
     * @param oldProjectsByIds Old Project-Maps is mandatory
     *
     * @return DUPProjectHandler
     */
    public DUPProjectHandler addOldProjects(Map<Id, Project__c> oldPARsByIds) {
        this.oldProjectsByIds = oldProjectsByIds;
        return this;
    }

    /**
     * Chain-Method to build the Handler
     *
     * @param newProjectsByIds New Project-Maps is mandatory
     *
     * @return DUPProjectHandler
     */
    public DUPProjectHandler addNewProjects(Map<Id, Project__c> newProjectsByIds) {
        this.newProjectsByIds = newProjectsByIds;
        return this;
    }

    /**
     * Update project helper field changes on beforeUpdate
     */
    public void handleProjectAddressChanges(Map<Id, Project__c> newProjectsByIds) {
        try {
            for(Project__c project : newProjectsByIds.values()) {
                //format project address
                if(project.Project_Address__Street__s != null) {
                    DUPDuplicateCheckHelper.FormattedAddress formattedAddress = DUPDuplicateCheckHelper.formatAddress(project.Project_Address__Street__s);
                    project.Street_cleaned__c =  formattedAddress.street;
                    project.House_Number_cleaned__c =  formattedAddress.streetNumber;
                } else {
                    project.Street_cleaned__c =  null;
                    project.House_Number_cleaned__c =  null;
                }
            }

            if(Test.isRunningTest() && testError) {
                throw new DMLException('Test Error');
            }
        } catch (Exception e) {
            createExceptionsPerProject(e, newProjectsByIds);
        }
    }


    /**
     * Creates Exceptions mapped by Project Ids
     *
     * @param e Single Exception to replicate by Project-Id
     * @param newProjectsByIds Project-Map
     */
    private void createExceptionsPerProject(Exception e, Map<Id, Project__c> newProjectsByIds) {
        for (Id projectId : newProjectsByIds.keySet()) {
            this.DUPProjectHandlerExceptions.put(projectId, new DUPProjectHandlerException(e.getMessage()));
        }

        //handle DUPProjectHandlerExceptions
        if (!this.DUPProjectHandlerExceptions.isEmpty()) {
            UTLErrorLog.insertErrorLogs(createsExceptionLogs(this.DUPProjectHandlerExceptions), CLASSNAME);
        }
    }

    /**
     * Maps DUPProjectHandlerException and Project-Id's to a List of Core_Error_Log__c.
     *
     * @param dupProjectHandlerExceptionsByProjectIds created Core_Error_Log__c list
     *
     * @return List of Core_Error_Log__c
     */
    private List<Core_Error_Log__c> createsExceptionLogs(Map<Id, DUPProjectHandlerException> dupProjectHandlerExceptionsByProjectIds) {
        List<Core_Error_Log__c> coreErrorLogs = new List<Core_Error_Log__c>();

        for (Id projectId : dupProjectHandlerExceptionsByProjectIds.keySet()) {
            DUPProjectHandlerException dUPProjectHandlerException = dupProjectHandlerExceptionsByProjectIds.get(projectId);

            System.debug('Exception occured:');
            System.debug('Message:' + dUPProjectHandlerException.getMessage());
            System.debug('Stack:' + dUPProjectHandlerException.getStackTraceString());
            System.debug('Line:' + dUPProjectHandlerException.getLineNumber());

            Core_Error_Log__c coreErrorLog = UTLErrorLog.createErrorLogRecord(
                CLASSNAME,
                dUPProjectHandlerException,
                'Error on Project Handling',
                projectId
            );
            coreErrorLogs.add(coreErrorLog);
        }
        return coreErrorLogs;
    }

    public class DUPProjectHandlerException extends Exception {
    }
}