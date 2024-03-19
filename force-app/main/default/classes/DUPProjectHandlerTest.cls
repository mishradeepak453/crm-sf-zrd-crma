/**
 * SF-1205: Test class for DUPProjectHandler
 *
 * @author  isabella.moos@accenture.com
 *
 * @version 2023-10-26      isabella.moos@accenture.com     creation
 */
@isTest
private with sharing class DUPProjectHandlerTest {
    private static final String SALESFORCE_PROJECT_RECORD_TYPE_NAME = 'Salesforce_Project';
    //private DUPProjectHandler dupProjectHandler = new DUPProjectHandler();

    /**
     * Creates test project, the creation needs to be placed seperately in an TestSetup method to avoid mixed dml operations
     */
    @TestSetup
    private static void createTestData() {
        //create projects
        List<Project__c> testProjectList = TESTDataFactory.createTestIBauProjects(1, SALESFORCE_PROJECT_RECORD_TYPE_NAME, false);
        testProjectList.addAll(TESTDataFactory.createTestIBauProjects(1, SALESFORCE_PROJECT_RECORD_TYPE_NAME, false));
        testProjectList.addAll(TESTDataFactory.createTestIBauProjects(1, SALESFORCE_PROJECT_RECORD_TYPE_NAME, false));
        testProjectList.addAll(TESTDataFactory.createTestIBauProjects(1, SALESFORCE_PROJECT_RECORD_TYPE_NAME, false));
        insert testProjectList;
    }

    /**
     * Test Project Address change
     * Street name changes or is removed
     * House Number changes or is removed
     */
    @isTest
    private static void testProjectAddressChanges() {
        List<Project__c> testProjectList = [SELECT Id, 
                Project_Address__Street__s, 
                Street_cleaned__c, 
                House_Number_cleaned__c 
            FROM Project__c];
        
        //verify old helper field values
        System.assertEquals('test', testProjectList[0].Street_cleaned__c);
        System.assertEquals('1', testProjectList[0].House_Number_cleaned__c);
        System.assertEquals('test', testProjectList[1].Street_cleaned__c);
        System.assertEquals('1', testProjectList[1].House_Number_cleaned__c);
        System.assertEquals('test', testProjectList[2].Street_cleaned__c);
        System.assertEquals('1', testProjectList[2].House_Number_cleaned__c);
        System.assertEquals('test', testProjectList[3].Street_cleaned__c);
        System.assertEquals('1', testProjectList[3].House_Number_cleaned__c);

        Test.startTest();
            testProjectList[0].Project_Address__Street__s = 'New Street 1';
            testProjectList[1].Project_Address__Street__s = 'New Street 2';
            testProjectList[2].Project_Address__Street__s = null;
            testProjectList[3].Project_Address__Street__s = 'New Street';
            update testProjectList; 
        Test.stopTest();

        List<Project__c> testProjectUpdatedList = [SELECT Id, 
                Project_Address__Street__s, 
                Street_cleaned__c, 
                House_Number_cleaned__c 
            FROM Project__c];

        //verify results
        System.assertEquals('news', testProjectUpdatedList[0].Street_cleaned__c);
        System.assertEquals('1', testProjectUpdatedList[0].House_Number_cleaned__c);
        System.assertEquals('news', testProjectUpdatedList[1].Street_cleaned__c);
        System.assertEquals('2', testProjectUpdatedList[1].House_Number_cleaned__c);
        System.assertEquals(null, testProjectUpdatedList[2].Street_cleaned__c);
        System.assertEquals(null, testProjectUpdatedList[2].House_Number_cleaned__c);
        System.assertEquals('news', testProjectUpdatedList[3].Street_cleaned__c);
        System.assertEquals(null, testProjectUpdatedList[3].House_Number_cleaned__c);
    }

    /**
     * Test Exception
     */
    @isTest
    private static void testException() {
        DUPProjectHandler projectHandler = new DUPProjectHandler();
        projectHandler.testError = true;

        List<Project__c> testProjectBeforeUpdateList = [SELECT Id, 
                Project_Address__Street__s, 
                Street_cleaned__c, 
                House_Number_cleaned__c 
            FROM Project__c 
            LIMIT 1];
        projectHandler.oldProjectsByIds = new Map<Id, Project__c>(testProjectBeforeUpdateList);

        List<Project__c> testProjectAfterUpdateList = [SELECT Id, 
                Project_Address__Street__s, 
                Street_cleaned__c, 
                House_Number_cleaned__c 
            FROM Project__c 
            LIMIT 1];
        testProjectAfterUpdateList[0].Project_Address__Street__s = 'New Street 1';
        Map<Id, Project__c> newProjectsByIds = new Map<Id, Project__c>(testProjectAfterUpdateList);
        projectHandler.newProjectsByIds = newProjectsByIds;

        Test.startTest();
            projectHandler.handleProjectAddressChanges(newProjectsByIds);
        Test.stopTest();

        //verify results
        List<Core_Error_Log__c> errorLogs = [SELECT Id, Core_Apex_Class__c FROM Core_Error_Log__c WHERE Core_Apex_Class__c = : projectHandler.CLASSNAME];
        System.assertEquals(1, errorLogs.size());
    }
}