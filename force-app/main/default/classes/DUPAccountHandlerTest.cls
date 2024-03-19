/**
 * SF-1205: Test class for DUPAccountHandler
 *
 * @author  isabella.moos@accenture.com
 *
 * @version 2023-10-24      isabella.moos@accenture.com     creation
 */
@IsTest
private with sharing class DUPAccountHandlerTest {
    private static final String ACCOUNT_RECORD_TYPE_NAME = 'ZR_Standard_Account_Customer';
    private static final String SALESFORCE_PROJECT_RECORD_TYPE_NAME = 'Salesforce_Project';

    /**
     * Creates test project, the creation needs to be placed seperately in an TestSetup method to avoid mixed dml operations
     */
    @TestSetup
    private static void createTestData() {
        //create accounts
        List<Account> testAccountList = TESTDataFactory.createTestAccounts(1, ACCOUNT_RECORD_TYPE_NAME, false);
        testAccountList.addAll(TESTDataFactory.createTestAccounts(1, ACCOUNT_RECORD_TYPE_NAME, false));
        testAccountList[1].Name = 'Test Acc 2';
        insert testAccountList;

        //create projects
        List<Project__c> testProjectList = TESTDataFactory.createTestIBauProjects(1, SALESFORCE_PROJECT_RECORD_TYPE_NAME, true);

        //create project account relations
        List<Project_Account_Relation__c> testPPARList = TESTDataFactory.createTestPARs(1, testAccountList[1], '1', testProjectList[0], false);
        testPPARList.addAll(TESTDataFactory.createTestPARs(1, testAccountList[1], '2', testProjectList[0], false));
        testPPARList.addAll(TESTDataFactory.createTestPARs(1, testAccountList[0], '1;3', testProjectList[0], false));
        testPPARList.addAll(TESTDataFactory.createTestPARs(1, testAccountList[0], '4', testProjectList[0], false));
        insert testPPARList;
    }

    /**
     * Test success scenario when account name is updated
     */
    @isTest
    private static void testAccountNameUpdate() {
        DUPAccountHandler handler = new DUPAccountHandler();
        Account acc = [SELECT 
                            Id, 
                            Name 
                        FROM Account 
                        WHERE Name LIKE 'ACN%'
                        LIMIT 1];
        Project__c project = [SELECT 
                        Id, 
                        Building_Owner_cleaned__c, 
                        Involved_Accounts_cleaned__c 
                    FROM Project__c 
                    LIMIT 1];
        
        System.assertEquals('acn,', project.Building_Owner_cleaned__c);
        System.assertEquals('test,test,acn,acn,', project.Involved_Accounts_cleaned__c);
        
        Test.startTest();
            acc.Name = 'Updated Account Name';
            update acc;
        Test.stopTest();

        Project__c updatedProject = [SELECT 
                                        Id, 
                                        Building_Owner_cleaned__c, 
                                        Involved_Accounts_cleaned__c 
                                    FROM Project__c 
                                    LIMIT 1];

        System.assertEquals('updated,', updatedProject.Building_Owner_cleaned__c);
        System.assertEquals('test,test,updated,updated,', updatedProject.Involved_Accounts_cleaned__c);

        //test if error logs inserted correctly
        List<Core_Error_Log__c> errorLogs = [SELECT Id, Core_Apex_Class__c FROM Core_Error_Log__c WHERE Core_Apex_Class__c = :handler.CLASSNAME];
        System.assertEquals(1, errorLogs.size());
    }
}