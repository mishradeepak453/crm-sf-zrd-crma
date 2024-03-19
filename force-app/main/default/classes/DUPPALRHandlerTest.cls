/**
 * SF-1205: Test class for DUPPALRHandler
 *
 * @author  isabella.moos@accenture.com
 *
 * @version 2023-10-23      isabella.moos@accenture.com     creation
 */
@IsTest
private with sharing class DUPPALRHandlerTest {
    private static final String ACCOUNT_LEAD_RECORD_TYPE_NAME = 'Account_Lead_Record_Type';
    private static final String SALESFORCE_PROJECT_RECORD_TYPE_NAME = 'Salesforce_Project';

    /**
     * Creates test project, the creation needs to be placed seperately in an TestSetup method to avoid mixed dml operations
     */
    @TestSetup
    private static void createTestData() {
        //create account leads
        List<Account_Lead__c> testAccountLeadList = TESTDataFactory.createTestAccountLeads(1, ACCOUNT_LEAD_RECORD_TYPE_NAME, false);
        testAccountLeadList.addAll(TESTDataFactory.createTestAccountLeads(1, ACCOUNT_LEAD_RECORD_TYPE_NAME, false));
        testAccountLeadList[1].Name = 'Test Acc 2';
        insert testAccountLeadList;

        //create projects
        List<Project__c> testProjectList = TESTDataFactory.createTestIBauProjects(1, SALESFORCE_PROJECT_RECORD_TYPE_NAME, false);
        testProjectList.addAll(TESTDataFactory.createTestIBauProjects(1, SALESFORCE_PROJECT_RECORD_TYPE_NAME, false));
        testProjectList[1].Name = 'New Project';
        insert testProjectList;

        //create project account lead relations
        List<Project_Account_Lead_Relation__c> testPPALRList = TESTDataFactory.createTestPALRs(1, testAccountLeadList[0], '1', testProjectList[0], false);
        testPPALRList.addAll(TESTDataFactory.createTestPALRs(1, testAccountLeadList[0], '3', testProjectList[0], false));
        testPPALRList.addAll(TESTDataFactory.createTestPALRs(1, testAccountLeadList[1], '2', testProjectList[0], false));
        testPPALRList.addAll(TESTDataFactory.createTestPALRs(1, testAccountLeadList[0], '2', testProjectList[1], false));
        insert testPPALRList;
    }

    /**
     * Test Project Account Lead Relation insert
     */
    @isTest
    private static void testInsertPALR() {
        Account_Lead__c accLead = [SELECT Id 
                        FROM Account_Lead__c 
                        WHERE Name LIKE 'ACN%'
                        LIMIT 1];
        Project__c project = [SELECT Id 
                                FROM Project__c 
                                LIMIT 1];

        Test.startTest();
            TESTDataFactory.createTestPALRs(1, accLead, '1', project, true);
        Test.stopTest();

        Project__c updatedProject = [SELECT 
                                        Id, 
                                        Involved_Accounts_cleaned__c,
                                        Building_Owner_cleaned__c,
                                        Building_Owner__c
                                    FROM Project__c 
                                    LIMIT 1];
        String updatedProjectId = updatedProject.id;
        List<Project_Account_Lead_Relation__c> palrList = [SELECT Id 
                                                    FROM Project_Account_Lead_Relation__c 
                                                    WHERE Project__c = :updatedProjectId];

        System.assertEquals(4, palrList.size());
        System.assertEquals('acn,test,acn,', updatedProject.Involved_Accounts_cleaned__c);
        System.assertEquals('acn,', updatedProject.Building_Owner_cleaned__c);
        System.assertEquals('ACN Test Account Lead0', updatedProject.Building_Owner__c);
    }

    /**
     * Test Project Account Lead Relation update of Account Role (Account Lead and Project cannot be reparented)
     */
    @isTest
    private static void testUpdatePAR() {
        Project__c project1 = [SELECT 
                                    Id,
                                    Involved_Accounts_cleaned__c,
                                    Building_Owner_cleaned__c,
                                    Building_Owner__c
                                FROM Project__c 
                                WHERE Name LIKE 'TEST%'
                                LIMIT 1];
        Project__c project2 = [SELECT 
                                    Id,
                                    Involved_Accounts_cleaned__c,
                                    Building_Owner_cleaned__c,
                                    Building_Owner__c
                                FROM Project__c 
                                WHERE Name LIKE 'NEW%'
                                LIMIT 1];

        String project1Id = project1.id;
        String project2Id = project2.id;
        List<Project_Account_Lead_Relation__c> palrList = new List<Project_Account_Lead_Relation__c>();
        List<Project_Account_Lead_Relation__c> palr1 = [SELECT Id
                                                FROM Project_Account_Lead_Relation__c 
                                                WHERE Project__c = :project1Id 
                                                LIMIT 2];
        Project_Account_Lead_Relation__c palr2 = [SELECT Id 
                                            FROM Project_Account_Lead_Relation__c 
                                            WHERE Project__c = :project2Id 
                                            AND Account_Role__c = '2'
                                            LIMIT 1];

        System.assertEquals('acn,test,', project1.Involved_Accounts_cleaned__c);
        System.assertEquals('acn,', project1.Building_Owner_cleaned__c);
        System.assertEquals('acn,', project2.Involved_Accounts_cleaned__c);
        System.assertEquals(null, project2.Building_Owner_cleaned__c);

        Test.startTest();
            palr1[1].Account_Role__c = '1';
            palr1[0].Account_Role__c = '3';
            palr2.Account_Role__c = '3';
            palrList.addAll(palr1);
            palrList.add(palr2);
            update palrList;
        Test.stopTest();

        List<Project__c> updatedProject = [SELECT 
                                        Id, 
                                        Involved_Accounts_cleaned__c,
                                        Building_Owner_cleaned__c 
                                    FROM Project__c 
                                    LIMIT 2];
        String updatedProjectId = updatedProject[0].id;
        List<Project_Account_Lead_Relation__c> updatedPALRList = [SELECT Id 
                                                    FROM Project_Account_Lead_Relation__c];

        System.assertEquals(4, updatedPALRList.size());
        System.assertEquals('test,acn,', updatedProject[0].Involved_Accounts_cleaned__c);
        System.assertEquals('acn,', updatedProject[0].Building_Owner_cleaned__c);
        System.assertEquals(null, updatedProject[1].Involved_Accounts_cleaned__c);
        System.assertEquals('acn,', updatedProject[1].Building_Owner_cleaned__c);
    }

    /**
     * Test Project Account Relation delete
     */
    @isTest
    private static void testDeletePAR() {
        DUPPALRHandler handler = new DUPPALRHandler();

        Project__c project = [SELECT Id 
                                FROM Project__c 
                                WHERE Name LIKE 'TEST%'
                                LIMIT 1];

        String projectId = project.id;
        List<Project_Account_Lead_Relation__c> palrList = [SELECT Id 
                                                    FROM Project_Account_Lead_Relation__c 
                                                    WHERE Project__c = :projectId LIMIT 3];

        Test.startTest();
            delete palrList;
        Test.stopTest();

        Project__c updatedProject = [SELECT 
                                        Id, 
                                        Involved_Accounts_cleaned__c,
                                        Building_Owner_cleaned__c 
                                    FROM Project__c 
                                    WHERE Name LIKE 'TEST%'
                                    LIMIT 1];
        String updatedProjectId = updatedProject.id;
        List<Project_Account_Lead_Relation__c> updatedPALRList = [SELECT Id 
                                                    FROM Project_Account_Lead_Relation__c 
                                                    WHERE Project__c = :updatedProjectId];

        System.assertEquals(0, updatedPALRList.size());
        System.assertEquals(null, updatedProject.Involved_Accounts_cleaned__c);
        System.assertEquals(null, updatedProject.Building_Owner_cleaned__c);
    }

    /**
     * Test Project Account Relation undelete
     */
    @isTest
    private static void testPARException() {
        DUPPALRHandler handler = new DUPPALRHandler();
        Project__c project = [SELECT Id 
                                FROM Project__c 
                                WHERE Name LIKE 'TEST%'
                                LIMIT 1];

        String projectId = project.id;
        List<Project_Account_Lead_Relation__c> palrList = [SELECT Id 
                                                    FROM Project_Account_Lead_Relation__c 
                                                    WHERE Project__c = :projectId LIMIT 3];

        Test.startTest();
            delete palrList;
            undelete palrList;
        Test.stopTest();

        // validate results
        List<Core_Error_Log__c> errorLogs = [SELECT Id, Core_Apex_Class__c FROM Core_Error_Log__c WHERE Core_Apex_Class__c = :handler.CLASSNAME];
        
        System.assertEquals(3, errorLogs.size());
    }
}