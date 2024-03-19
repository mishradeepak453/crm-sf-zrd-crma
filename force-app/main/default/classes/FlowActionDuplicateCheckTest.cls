/**
 * SF-1205: Test class for FlowActionDuplicateCheck
 *
 * @author  isabella.moos@accenture.com
 *
 * @version 2023-10-25      isabella.moos@accenture.com     creation
 */
@IsTest
private with sharing class FlowActionDuplicateCheckTest {
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

        //create account leads
        List<Account_Lead__c> testAccountLeadList = TESTDataFactory.createTestAccountLeads(1, ACCOUNT_LEAD_RECORD_TYPE_NAME, false);
        testAccountLeadList.addAll(TESTDataFactory.createTestAccountLeads(1, ACCOUNT_LEAD_RECORD_TYPE_NAME, false));
        testAccountLeadList[1].Name = 'Test Acc 2';
        insert testAccountLeadList;

        //create projects
        List<Project__c> testProjectList = TESTDataFactory.createTestIBauProjects(2, SALESFORCE_PROJECT_RECORD_TYPE_NAME, true);

        //create project account relations
        List<Project_Account_Relation__c> testPPARList = TESTDataFactory.createTestPARs(1, testAccountList[1], '1', testProjectList[0], false);
        testPPARList.addAll(TESTDataFactory.createTestPARs(1, testAccountList[0], '2', testProjectList[0], false));
        testPPARList.addAll(TESTDataFactory.createTestPARs(1, testAccountList[0], '1;3', testProjectList[0], false));
        testPPARList.addAll(TESTDataFactory.createTestPARs(1, testAccountList[1], '1', testProjectList[1], false));
        testPPARList.addAll(TESTDataFactory.createTestPARs(1, testAccountList[0], '2', testProjectList[1], false));
        testPPARList.addAll(TESTDataFactory.createTestPARs(1, testAccountList[0], '1;3', testProjectList[1], false));
        insert testPPARList;

        //create project account lead relations
        List<Project_Account_Lead_Relation__c> testPPALRList = TESTDataFactory.createTestPALRs(1, testAccountLeadList[1], '1', testProjectList[0], false);
        testPPALRList.addAll(TESTDataFactory.createTestPALRs(1, testAccountLeadList[0], '3', testProjectList[0], false));
        testPPALRList.addAll(TESTDataFactory.createTestPALRs(1, testAccountLeadList[0], '2', testProjectList[0], false));
        testPPALRList.addAll(TESTDataFactory.createTestPALRs(1, testAccountLeadList[1], '1', testProjectList[1], false));
        testPPALRList.addAll(TESTDataFactory.createTestPALRs(1, testAccountLeadList[0], '3', testProjectList[1], false));
        testPPALRList.addAll(TESTDataFactory.createTestPALRs(1, testAccountLeadList[0], '2', testProjectList[1], false));
        insert testPPALRList;
    }

    /**
     * Test InitDuplicateCheck method With Existing Project record (relevant for data creanse activities)
     */
    @isTest
    private static void testInitDuplicateCheckWithExistingProject() {
        List<FlowActionDuplicateCheck.InputVariables> inputVariables = new List<FlowActionDuplicateCheck.InputVariables>();
        List<FlowActionDuplicateCheck.OutputVariables> outputVariables = new List<FlowActionDuplicateCheck.OutputVariables>();

        Map<Id,Project__c> projectMap = new Map<Id,Project__c>();
        List<Project__c> projectList = new List<Project__c> ();

        //query test record
        for(Project__c project : [SELECT 
                                    id, 
                                    Involved_Accounts_cleaned__c,
                                    Building_Owner_cleaned__c,
                                    Street_cleaned__c,
                                    House_Number_cleaned__c, 
                                    Project_Address__Street__s,
                                    (SELECT Id, Account__c, Account__r.Name, Project__c, Account_Role__c FROM Project_Account_Relations__r),
                                    (SELECT Id, Account_Lead__c, Account_Lead__r.Name, Project__c, Account_Role__c FROM Project_Account_Lead_Relations__r)  
                                FROM Project__c 
                                LIMIT 1]) {

            // reset helper fields
            project.Involved_Accounts_cleaned__c = null;
            project.Building_Owner_cleaned__c = null;
            project.Street_cleaned__c = null;
            project.House_Number_cleaned__c = null;
            List<Project_Account_Relation__c> projectAccountRelations = new List<Project_Account_Relation__c>();
            List<Account> relatedAccountsList = new List<Account>();
            List<Project_Account_Lead_Relation__c> projectAccountLeadRelations = new List<Project_Account_Lead_Relation__c>();
            List<Account_Lead__c> relatedAccountLeadsList = new List<Account_Lead__c>();

            if(project.Project_Account_Lead_Relations__r.size() > 0) {
                projectMap.put(project.id, project);
                for(Project_Account_Lead_Relation__c palr : project.Project_Account_Lead_Relations__r) {
                    projectAccountLeadRelations.add(palr);
                    Account_Lead__c accLead = new Account_Lead__c(
                        Id = palr.Account_Lead__c,
                        Name = palr.Account_Lead__r.Name
                    );
                    relatedAccountLeadsList.add(accLead);
                }
            }
            if(project.Project_Account_Relations__r.size() > 0) {
                projectMap.put(project.id, project);
                for(Project_Account_Relation__c par : project.Project_Account_Relations__r) {
                    projectAccountRelations.add(par);
                    Account acc = new Account(
                        Id = par.Account__c,
                        Name = par.Account__r.Name
                    );
                    relatedAccountsList.add(acc);
                }
            }
            if(projectMap.get(project.id) != null) {
                FlowActionDuplicateCheck.InputVariables input = new FlowActionDuplicateCheck.InputVariables();
                input.project = project;
                input.projectAccountRelations = projectAccountRelations;
                input.relatedAccountsList = relatedAccountsList;
                input.projectAccountLeadRelations = projectAccountLeadRelations;
                input.relatedAccountLeadsList = relatedAccountLeadsList;
                input.cleanseProjectFields = true;
                input.executeDuplicateCheck = false;
                inputVariables.add(input);
            }
        }

        //check that helper fields are empty
        System.assertEquals(null, projectMap.values()[0].Involved_Accounts_cleaned__c);
        System.assertEquals(null, projectMap.values()[0].Building_Owner_cleaned__c);
        System.assertEquals(null, projectMap.values()[0].Street_cleaned__c);
        System.assertEquals(null, projectMap.values()[0].House_Number_cleaned__c);

        Test.startTest();
            outputVariables = FlowActionDuplicateCheck.initDuplicateCheck(inputVariables);
        Test.stopTest();

        //verify results
        System.assertEquals('test,acn,test,acn,acn,', outputVariables[0].flowProject.Involved_Accounts_cleaned__c);
        System.assertEquals('acn,', outputVariables[0].flowProject.Building_Owner_cleaned__c);
        System.assertEquals('test', outputVariables[0].flowProject.Street_cleaned__c);
        System.assertEquals('1', outputVariables[0].flowProject.House_Number_cleaned__c);
    }

    /**
     * Test InitDuplicateCheck method With New Project record (relevant for project creation flow)
     */
    @isTest
    private static void testInitDuplicateCheckWithNewProject() {
        List<FlowActionDuplicateCheck.InputVariables> inputVariables = new List<FlowActionDuplicateCheck.InputVariables>();
        List<FlowActionDuplicateCheck.OutputVariables> outputVariables = new List<FlowActionDuplicateCheck.OutputVariables>();
        List<Account> testAccountList = [SELECT Id, Name FROM Account LIMIT 2];
        List<Account_Lead__c> testAccountLeadList = [SELECT Id, Name FROM Account_Lead__c LIMIT 2];
    
        // prepare data without inserting as in flow
        List<Project__c> testProjectList = TESTDataFactory.createTestIBauProjects(1, SALESFORCE_PROJECT_RECORD_TYPE_NAME, false);
        testProjectList[0].Street_cleaned__c = null;
        testProjectList[0].House_Number_cleaned__c = null;
        
        List<Project_Account_Relation__c> testPPARList = TESTDataFactory.createTestPARs(1, testAccountList[1], '1', testProjectList[0], false);
        testPPARList.addAll(TESTDataFactory.createTestPARs(1, testAccountList[0], '2', testProjectList[0], false));
        testPPARList.addAll(TESTDataFactory.createTestPARs(1, testAccountList[0], '1;3', testProjectList[0], false));

        FlowActionDuplicateCheck.InputVariables input = new FlowActionDuplicateCheck.InputVariables();
        input.project = testProjectList[0];
        input.projectAccountRelations = testPPARList;
        input.cleanseProjectFields = true;
        input.executeDuplicateCheck = false;
        inputVariables.add(input);

        //check that helper fields are empty
        System.assertEquals(null, testProjectList[0].Involved_Accounts_cleaned__c);
        System.assertEquals(null, testProjectList[0].Building_Owner_cleaned__c);
        System.assertEquals(null, testProjectList[0].Street_cleaned__c);
        System.assertEquals(null, testProjectList[0].House_Number_cleaned__c);

        Test.startTest();
            outputVariables = FlowActionDuplicateCheck.initDuplicateCheck(inputVariables);
        Test.stopTest();

        //verify results
        System.assertEquals('test,acn,acn,', outputVariables[0].flowProject.Involved_Accounts_cleaned__c);
        System.assertEquals('acn,', outputVariables[0].flowProject.Building_Owner_cleaned__c);
        System.assertEquals('test', outputVariables[0].flowProject.Street_cleaned__c);
        System.assertEquals('1', outputVariables[0].flowProject.House_Number_cleaned__c);
    }

    /**
     * Test InitDuplicateCheck method With New Project record including duplicate check (relevant for project creation flow)
     * Potential duplicate due to street and street number check
     */
    @isTest
    private static void testDuplicateCheck1WithNewProject() {
        List<FlowActionDuplicateCheck.InputVariables> inputVariables = new List<FlowActionDuplicateCheck.InputVariables>();
        List<FlowActionDuplicateCheck.OutputVariables> outputVariables = new List<FlowActionDuplicateCheck.OutputVariables>();
        List<Account> testAccountList = [SELECT 
                Id, 
                Name 
            FROM Account 
            LIMIT 2];
        
        // prepare data without inserting as in flow
        List<Project__c> testProjectList = [SELECT 
                Id, 
                Name, 
                Project_Construction_Progress__c,
                Street__c,
                Project_Address__Street__s,
                Postal_Code__c,
                City__c,
                Total_Volume__c,
                Project_Construction_Start__c,
                Potential__c,
                Core_Source_System__c, 
                Project_Address__c, 
                Project_Address__Longitude__s, 
                Project_Address__Latitude__s, 
                Project_Address__PostalCode__s, 
                Street_cleaned__c, 
                House_Number_cleaned__c,
                Involved_Accounts_cleaned__c,
                Building_Owner_cleaned__c,
                Building_Owner__c,
                Owner.Name,
                OwnerId,
                CreatedDate
            FROM Project__c 
            LIMIT 2];
        String projectId = testProjectList[0].Id;
        
        List<Project_Account_Relation__c> testPPARList = [SELECT 
                Id, 
                Account__c, 
                Project__c, 
                Account_Role__c 
            FROM Project_Account_Relation__c 
            WHERE Project__c = :projectId];

        FlowActionDuplicateCheck.InputVariables input = new FlowActionDuplicateCheck.InputVariables();
        input.project = testProjectList[0];
        input.projectAccountRelations = testPPARList;
        input.cleanseProjectFields = true;
        input.executeDuplicateCheck = true;
        inputVariables.add(input);

        Test.startTest();
            outputVariables = FlowActionDuplicateCheck.initDuplicateCheck(inputVariables);
        Test.stopTest();

        //verify results
        System.assertEquals(true, outputVariables[0].potentialDuplicateProjectAvailable);
        System.assertEquals(2, outputVariables[0].potentialDuplicateProjectList.size());
    }

    /**
     * Test InitDuplicateCheck method With New Project record including duplicate check (relevant for project creation flow)
     * Potential duplicate due to building owner check
     */
    @isTest
    private static void testDuplicateCheck2WithNewProject() {
        List<FlowActionDuplicateCheck.InputVariables> inputVariables = new List<FlowActionDuplicateCheck.InputVariables>();
        List<FlowActionDuplicateCheck.OutputVariables> outputVariables = new List<FlowActionDuplicateCheck.OutputVariables>();
        List<Account> testAccountList = [SELECT 
                Id, 
                Name 
            FROM Account 
            LIMIT 2];
        
        // prepare data without inserting as in flow
        List<Project__c> testProjectList = [SELECT 
                Id, 
                Name, 
                Project_Construction_Progress__c,
                Street__c,
                Project_Address__Street__s,
                Postal_Code__c,
                City__c,
                Total_Volume__c,
                Project_Construction_Start__c,
                Potential__c,
                Core_Source_System__c, 
                Project_Address__c, 
                Project_Address__Longitude__s, 
                Project_Address__Latitude__s, 
                Project_Address__PostalCode__s, 
                Street_cleaned__c, 
                House_Number_cleaned__c,
                Involved_Accounts_cleaned__c,
                Building_Owner_cleaned__c,
                Building_Owner__c,
                Owner.Name,
                OwnerId,
                CreatedDate
            FROM Project__c 
            LIMIT 2];
        String projectId = testProjectList[0].Id;
        
        List<Project_Account_Relation__c> testPPARList = [SELECT 
                Id, 
                Account__c, 
                Project__c, 
                Account_Role__c 
            FROM Project_Account_Relation__c 
            WHERE Project__c = :projectId];

        testProjectList[0].House_Number_cleaned__c = '2';
        update testProjectList;

        FlowActionDuplicateCheck.InputVariables input = new FlowActionDuplicateCheck.InputVariables();
        input.project = testProjectList[0];
        input.projectAccountRelations = testPPARList;
        input.cleanseProjectFields = true;
        input.executeDuplicateCheck = true;
        inputVariables.add(input);

        Test.startTest();
            outputVariables = FlowActionDuplicateCheck.initDuplicateCheck(inputVariables);
        Test.stopTest();

        //verify results
        System.assertEquals(true, outputVariables[0].potentialDuplicateProjectAvailable);
        System.assertEquals(2, outputVariables[0].potentialDuplicateProjectList.size());
    }

    /**
     * Test InitDuplicateCheck method With New Project record including duplicate check (relevant for project creation flow)
     * Potential duplicate due to involved accounts check
     */
    @isTest
    private static void testDuplicateCheck3WithNewProject() {
        List<FlowActionDuplicateCheck.InputVariables> inputVariables = new List<FlowActionDuplicateCheck.InputVariables>();
        List<FlowActionDuplicateCheck.OutputVariables> outputVariables = new List<FlowActionDuplicateCheck.OutputVariables>();
        List<Account> testAccountList = [SELECT 
                Id, 
                Name 
            FROM Account 
            LIMIT 2];
        
        // prepare data without inserting as in flow
        List<Project__c> testProjectList = [SELECT 
                Id, 
                Name, 
                Project_Construction_Progress__c,
                Street__c,
                Project_Address__Street__s,
                Postal_Code__c,
                City__c,
                Total_Volume__c,
                Project_Construction_Start__c,
                Potential__c,
                Core_Source_System__c, 
                Project_Address__c, 
                Project_Address__Longitude__s, 
                Project_Address__Latitude__s, 
                Project_Address__PostalCode__s, 
                Street_cleaned__c, 
                House_Number_cleaned__c,
                Involved_Accounts_cleaned__c,
                Building_Owner_cleaned__c,
                Building_Owner__c,
                Owner.Name,
                OwnerId,
                CreatedDate
            FROM Project__c 
            LIMIT 2];
        String projectId = testProjectList[0].Id;
        
        List<Project_Account_Relation__c> testPPARList = [SELECT 
                Id, 
                Account__c, 
                Project__c, 
                Account_Role__c 
            FROM Project_Account_Relation__c 
            WHERE Project__c = :projectId];

        testProjectList[0].House_Number_cleaned__c = '2';
        testProjectList[0].Building_Owner_cleaned__c = null;
        testProjectList[1].Building_Owner_cleaned__c = null;
        update testProjectList;

        FlowActionDuplicateCheck.InputVariables input = new FlowActionDuplicateCheck.InputVariables();
        input.project = testProjectList[0];
        input.projectAccountRelations = testPPARList;
        input.cleanseProjectFields = true;
        input.executeDuplicateCheck = true;
        inputVariables.add(input);

        Test.startTest();
            outputVariables = FlowActionDuplicateCheck.initDuplicateCheck(inputVariables);
        Test.stopTest();

        //verify results
        System.assertEquals(true, outputVariables[0].potentialDuplicateProjectAvailable);
        System.assertEquals(2, outputVariables[0].potentialDuplicateProjectList.size());
    }

    /**
     * Test InitDuplicateCheck method With New Project record including duplicate check (relevant for project creation flow)
     * Potential duplicate due to geolocation
     */
    @isTest
    private static void testDuplicateCheck4WithNewProject() {
        List<FlowActionDuplicateCheck.InputVariables> inputVariables = new List<FlowActionDuplicateCheck.InputVariables>();
        List<FlowActionDuplicateCheck.OutputVariables> outputVariables = new List<FlowActionDuplicateCheck.OutputVariables>();
        List<Account> testAccountList = [SELECT 
                Id, 
                Name 
            FROM Account 
            LIMIT 2];
        
        // prepare data without inserting as in flow
        List<Project__c> testProjectList = [SELECT 
                Id, 
                Name, 
                Project_Construction_Progress__c,
                Street__c,
                Project_Address__Street__s,
                Postal_Code__c,
                City__c,
                Total_Volume__c,
                Project_Construction_Start__c,
                Potential__c,
                Core_Source_System__c, 
                Project_Address__c, 
                Project_Address__Longitude__s, 
                Project_Address__Latitude__s, 
                Project_Address__PostalCode__s, 
                Street_cleaned__c, 
                House_Number_cleaned__c,
                Involved_Accounts_cleaned__c,
                Building_Owner_cleaned__c,
                Building_Owner__c,
                Owner.Name,
                OwnerId,
                CreatedDate
            FROM Project__c 
            LIMIT 2];
        String projectId = testProjectList[0].Id;
        
        List<Project_Account_Relation__c> testPPARList = [SELECT 
                Id, 
                Account__c, 
                Project__c, 
                Account_Role__c 
            FROM Project_Account_Relation__c 
            WHERE Project__c = :projectId];

        testProjectList[0].Project_Address__Longitude__s = 1.000;
        testProjectList[0].Project_Address__Latitude__s = 1.000;
        testProjectList[1].Project_Address__Longitude__s = 1.000;
        testProjectList[1].Project_Address__Latitude__s = 1.000;
        update testProjectList;

        FlowActionDuplicateCheck.InputVariables input = new FlowActionDuplicateCheck.InputVariables();
        input.project = testProjectList[0];
        input.projectAccountRelations = testPPARList;
        input.cleanseProjectFields = true;
        input.executeDuplicateCheck = true;
        inputVariables.add(input);

        Test.startTest();
            outputVariables = FlowActionDuplicateCheck.initDuplicateCheck(inputVariables);
        Test.stopTest();

        //verify results
        System.assertEquals(true, outputVariables[0].potentialDuplicateProjectAvailable);
        System.assertEquals(2, outputVariables[0].potentialDuplicateProjectList.size());
    }

    /**
     * Test InitDuplicateCheck method With New Project record including duplicate check (relevant for project creation flow)
     * No ootential duplicate
     */
    @isTest
    private static void testDuplicateCheck5WithNewProject() {
        List<FlowActionDuplicateCheck.InputVariables> inputVariables = new List<FlowActionDuplicateCheck.InputVariables>();
        List<FlowActionDuplicateCheck.OutputVariables> outputVariables = new List<FlowActionDuplicateCheck.OutputVariables>();
        List<Account> testAccountList = [SELECT 
                Id, 
                Name 
            FROM Account 
            LIMIT 2];
        
        // prepare data without inserting as in flow
        List<Project__c> testProjectList = [SELECT 
                Id, 
                Name, 
                Project_Construction_Progress__c,
                Street__c,
                Project_Address__Street__s,
                Postal_Code__c,
                City__c,
                Total_Volume__c,
                Project_Construction_Start__c,
                Potential__c,
                Core_Source_System__c, 
                Project_Address__c, 
                Project_Address__Longitude__s, 
                Project_Address__Latitude__s, 
                Project_Address__PostalCode__s, 
                Street_cleaned__c, 
                House_Number_cleaned__c,
                Involved_Accounts_cleaned__c,
                Building_Owner_cleaned__c,
                Building_Owner__c,
                Owner.Name,
                OwnerId,
                CreatedDate
            FROM Project__c 
            LIMIT 2];
        String projectId = testProjectList[0].Id;
        
        List<Project_Account_Relation__c> testPPARList = [SELECT 
                Id, 
                Account__c, 
                Project__c, 
                Account_Role__c 
            FROM Project_Account_Relation__c 
            WHERE Project__c = :projectId];

        testProjectList[0].Street_cleaned__c =  null;
        testProjectList[1].Street_cleaned__c =  null;
        update testProjectList;

        FlowActionDuplicateCheck.InputVariables input = new FlowActionDuplicateCheck.InputVariables();
        input.project = testProjectList[0];
        input.projectAccountRelations = testPPARList;
        input.cleanseProjectFields = true;
        input.executeDuplicateCheck = true;
        inputVariables.add(input);

        Test.startTest();
            outputVariables = FlowActionDuplicateCheck.initDuplicateCheck(inputVariables);
        Test.stopTest();

        //verify results
        System.assertEquals(false, outputVariables[0].potentialDuplicateProjectAvailable);
        System.assertEquals(0, outputVariables[0].potentialDuplicateProjectList.size());
    }
}