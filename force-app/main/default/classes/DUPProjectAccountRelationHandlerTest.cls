/**
 * SF-1205: Test class for DUPProjectAccountRelationHandler
 *
 * @author  isabella.moos@accenture.com
 *
 * @version 2023-10-23      isabella.moos@accenture.com     creation
 */
@IsTest
private with sharing class DUPProjectAccountRelationHandlerTest {
    private static final String ACCOUNT_RECORD_TYPE_NAME = 'ZR_Standard_Account_Customer';
    private static final String ACCOUNT_LEAD_RECORD_TYPE_NAME = 'Account_Lead_Record_Type';
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
        List<Project__c> testProjectList = TESTDataFactory.createTestIBauProjects(1, SALESFORCE_PROJECT_RECORD_TYPE_NAME, false);
        testProjectList.addAll(TESTDataFactory.createTestIBauProjects(1, SALESFORCE_PROJECT_RECORD_TYPE_NAME, false));
        testProjectList.addAll(TESTDataFactory.createTestIBauProjects(1, SALESFORCE_PROJECT_RECORD_TYPE_NAME, false));
        testProjectList[1].Name = 'New Project';
        testProjectList[2].Name = 'B New Project';
        insert testProjectList;

        //create project account relations
        List<Project_Account_Relation__c> testPPARList = TESTDataFactory.createTestPARs(1, testAccountList[0], '1', testProjectList[0], false);
        testPPARList.addAll(TESTDataFactory.createTestPARs(1, testAccountList[0], '2', testProjectList[0], false));
        testPPARList.addAll(TESTDataFactory.createTestPARs(1, testAccountList[0], '1;3', testProjectList[0], false));
        testPPARList.addAll(TESTDataFactory.createTestPARs(1, testAccountList[0], '2', testProjectList[1], false));
        testPPARList.addAll(TESTDataFactory.createTestPARs(1, testAccountList[0], '3', testProjectList[2], false));
        insert testPPARList;

        //create account leads
        List<Account_Lead__c> testAccountLeadList = TESTDataFactory.createTestAccountLeads(1, ACCOUNT_LEAD_RECORD_TYPE_NAME, false);
        testAccountLeadList[0].Name = 'Lead';
        insert testAccountLeadList;

        //create project account lead relations
        List<Project_Account_Lead_Relation__c> testPPALRList = TESTDataFactory.createTestPALRs(1, testAccountLeadList[0], '3', testProjectList[2], true);
    }

    /**
     * Test Project Account Relation insert
     */
    @isTest
    private static void testInsertPAR() {
        Account acc = [SELECT Id 
                        FROM Account 
                        WHERE Name LIKE 'ACN%'
                        LIMIT 1];
        Project__c project = [SELECT Id 
                                FROM Project__c 
                                LIMIT 1];

        Test.startTest();
            TESTDataFactory.createTestPARs(1, acc, '1', project, true);
        Test.stopTest();

        Project__c updatedProject = [SELECT 
                                        Id, 
                                        Involved_Accounts_cleaned__c,
                                        Building_Owner_cleaned__c 
                                    FROM Project__c 
                                    LIMIT 1];
        String updatedProjectId = updatedProject.id;
        List<Project_Account_Relation__c> parList = [SELECT Id 
                                                    FROM Project_Account_Relation__c 
                                                    WHERE Project__c = :updatedProjectId];

        System.assertEquals(4, parList.size());
        System.assertEquals('acn,acn,acn,acn,', updatedProject.Involved_Accounts_cleaned__c);
        System.assertEquals('acn,', updatedProject.Building_Owner_cleaned__c);
    }

    /**
     * Test Project Account Relation update of Account Role, Account or Project
     */
    @isTest
    private static void testUpdatePAR() {
        Account acc2 = [SELECT Id 
                            FROM Account 
                            WHERE Name LIKE 'Test%'
                            LIMIT 1];
        Project__c project1 = [SELECT 
                                    Id, 
                                    Involved_Accounts_cleaned__c,
                                    Building_Owner_cleaned__c 
                                FROM Project__c 
                                WHERE Name LIKE 'TEST%'
                                LIMIT 1];
        Project__c project2 = [SELECT 
                                    Id, 
                                    Involved_Accounts_cleaned__c,
                                    Building_Owner_cleaned__c 
                                FROM Project__c 
                                WHERE Name LIKE 'New%'
                                LIMIT 1];
        Project__c project3 = [SELECT 
                                Id, 
                                Involved_Accounts_cleaned__c,
                                Building_Owner_cleaned__c 
                            FROM Project__c 
                            WHERE Name LIKE 'B New%'
                            LIMIT 1];

        String project1Id = project1.id;
        String project3Id = project3.id;
        List<Project_Account_Relation__c> parList = new List<Project_Account_Relation__c>();
        Project_Account_Relation__c par1 = [SELECT Id 
                                            FROM Project_Account_Relation__c 
                                            WHERE Project__c = :project1Id 
                                            AND Account_Role__c = '1;3'
                                            LIMIT 1];
        Project_Account_Relation__c par2 = [SELECT Id 
                                            FROM Project_Account_Relation__c 
                                            WHERE Project__c = :project1Id 
                                            AND Account_Role__c = '1'
                                            LIMIT 1];
        List<Project_Account_Relation__c> par3 = [SELECT Id 
                                            FROM Project_Account_Relation__c 
                                            WHERE Account_Role__c = '2'
                                            LIMIT 2];
        Project_Account_Relation__c par4 = [SELECT Id 
                                            FROM Project_Account_Relation__c 
                                            WHERE Project__c = :project3Id
                                            LIMIT 1];
        
        System.assertEquals('acn,acn,acn,', project1.Involved_Accounts_cleaned__c);
        System.assertEquals('acn,', project1.Building_Owner_cleaned__c);
        System.assertEquals('acn,', project2.Involved_Accounts_cleaned__c);
        System.assertEquals(null, project2.Building_Owner_cleaned__c);
        System.assertEquals(null, project3.Involved_Accounts_cleaned__c);
        System.assertEquals('acn,', project3.Building_Owner_cleaned__c);

        Test.startTest();
            par1.Account_Role__c = '1';
            par2.Account__c = acc2.Id;
            par3[0].Project__c = project2.Id;
            par3[1].Account_Role__c = '3';
            par4.Account_Role__c = '1';
            parList.add(par1);
            parList.add(par2);
            parList.addAll(par3);
            parList.add(par4);
            update parList;
        Test.stopTest();

        List<Project__c> updatedProject = [SELECT 
                                        Id, 
                                        Involved_Accounts_cleaned__c,
                                        Building_Owner_cleaned__c 
                                    FROM Project__c 
                                    LIMIT 3];
        String updatedProjectId = updatedProject[0].id;
        List<Project_Account_Relation__c> updatedPARList = [SELECT Id 
                                                    FROM Project_Account_Relation__c];

        System.assertEquals(5, updatedPARList.size());
        System.assertEquals('test,acn,', updatedProject[0].Involved_Accounts_cleaned__c);
        System.assertEquals(null, updatedProject[0].Building_Owner_cleaned__c);
        System.assertEquals('acn,', updatedProject[1].Involved_Accounts_cleaned__c);
        System.assertEquals('acn,', updatedProject[1].Building_Owner_cleaned__c);
        System.assertEquals('acn,', updatedProject[2].Involved_Accounts_cleaned__c);
        System.assertEquals('lead,', updatedProject[2].Building_Owner_cleaned__c);
    }

    /**
     * Test Project Account Relation delete
     */
    @isTest
    private static void testDeletePAR() {
        Project__c project = [SELECT Id 
                                FROM Project__c 
                                WHERE Name LIKE 'TEST%'
                                LIMIT 1];

        String projectId = project.id;
        List<Project_Account_Relation__c> parList = [SELECT Id 
                                                    FROM Project_Account_Relation__c 
                                                    WHERE Project__c = :projectId LIMIT 3];

        Test.startTest();
            delete parList;
        Test.stopTest();

        Project__c updatedProject = [SELECT 
                                        Id, 
                                        Involved_Accounts_cleaned__c,
                                        Building_Owner_cleaned__c 
                                    FROM Project__c 
                                    LIMIT 1];
        String updatedProjectId = updatedProject.id;
        List<Project_Account_Relation__c> updatedPARList = [SELECT Id 
                                                    FROM Project_Account_Relation__c 
                                                    WHERE Project__c = :updatedProjectId];

        System.assertEquals(0, updatedPARList.size());
        System.assertEquals(null, updatedProject.Involved_Accounts_cleaned__c);
        System.assertEquals(null, updatedProject.Building_Owner_cleaned__c);
    }

    /**
     * Test Project Account Relation undelete
     */
    @isTest
    private static void testPARException() {
        DUPProjectAccountRelationHandler handler = new DUPProjectAccountRelationHandler();
        Project__c project = [SELECT Id 
                                FROM Project__c 
                                WHERE Name LIKE 'TEST%'
                                LIMIT 1];

        String projectId = project.id;
        List<Project_Account_Relation__c> parList = [SELECT Id 
                                                    FROM Project_Account_Relation__c 
                                                    WHERE Project__c = :projectId LIMIT 2];

        Test.startTest();
            delete parList;
            undelete parList;
        Test.stopTest();

        List<Core_Error_Log__c> errorLogs = [SELECT Id, Core_Apex_Class__c FROM Core_Error_Log__c WHERE Core_Apex_Class__c = :handler.CLASSNAME];
        System.assertEquals(2, errorLogs.size());
    }
}