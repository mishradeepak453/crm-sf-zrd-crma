/**
 * SF-1205: Test class for DUPAccountLeadHandler
 *
 * @author  isabella.moos@accenture.com
 *
 * @version 2023-10-24      isabella.moos@accenture.com     creation
 */
@IsTest
private with sharing class DUPAccountLeadHandlerTest {
    private static String ACCOUNT_LEAD_RECORD_TYPE_NAME = 'Account_Lead_Record_Type';
    private static final String SALESFORCE_PROJECT_RECORD_TYPE_NAME = 'Salesforce_Project';

    /**
     * Creates test project, the creation needs to be placed seperately in an TestSetup method to avoid mixed dml operations
     */
    @TestSetup
    private static void createTestData() {
        //create accounts
        List<Account_Lead__c> testAccountLeadList = TESTDataFactory.createTestAccountLeads(1, ACCOUNT_LEAD_RECORD_TYPE_NAME, false);
        testAccountLeadList.addAll(TESTDataFactory.createTestAccountLeads(1, ACCOUNT_LEAD_RECORD_TYPE_NAME, false));
        testAccountLeadList[1].Name = 'Test Acc Lead 2';
        insert testAccountLeadList;

        //create projects
        List<Project__c> testProjectList = TESTDataFactory.createTestIBauProjects(1, SALESFORCE_PROJECT_RECORD_TYPE_NAME, true);

        //create project account relations
        List<Project_Account_Lead_Relation__c> testPPALRList = TESTDataFactory.createTestPALRs(1, testAccountLeadList[1], '1', testProjectList[0], false);
        testPPALRList.addAll(TESTDataFactory.createTestPALRs(1, testAccountLeadList[0], '3', testProjectList[0], false));
        testPPALRList.addAll(TESTDataFactory.createTestPALRs(1, testAccountLeadList[0], '2', testProjectList[0], false));
        insert testPPALRList;
    }

    /**
     * Test success scenario when account name is updated
     */
    @isTest
    private static void testAccountNameUpdate() {
        DUPAccountLeadHandler handler = new DUPAccountLeadHandler();
        Account_Lead__c accLead = [SELECT 
                            Id, 
                            Name 
                        FROM Account_Lead__c 
                        WHERE Name LIKE 'ACN%'
                        LIMIT 1];
        Project__c project = [SELECT 
                        Id, 
                        Building_Owner_cleaned__c, 
                        Involved_Accounts_cleaned__c 
                    FROM Project__c 
                    LIMIT 1];
        
        System.assertEquals('acn,', project.Building_Owner_cleaned__c);
        System.assertEquals('test,acn,', project.Involved_Accounts_cleaned__c);
        
        Test.startTest();
            accLead.Name = 'Updated Account Lead Name';
            update accLead;
        Test.stopTest();

        Project__c updatedProject = [SELECT 
                                        Id, 
                                        Building_Owner_cleaned__c, 
                                        Involved_Accounts_cleaned__c 
                                    FROM Project__c 
                                    LIMIT 1];

        System.assertEquals('updated,', updatedProject.Building_Owner_cleaned__c);
        System.assertEquals('test,updated,', updatedProject.Involved_Accounts_cleaned__c);

        //test if error logs inserted correctly
        List<Core_Error_Log__c> errorLogs = [SELECT Id, Core_Apex_Class__c FROM Core_Error_Log__c WHERE Core_Apex_Class__c = :handler.CLASSNAME];
        System.assertEquals(1, errorLogs.size());
    }
}