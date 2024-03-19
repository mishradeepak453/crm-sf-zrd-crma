/**
 * SF-1014:  test class for BISProjectDeletionBatch
 * 
 * @author  miriam.ida.tyroller@accenture.com
 * 
 * @version 2023-07-31  miriam.ida.tyroller       creation
 */
@IsTest
public with sharing class BISProjectDeletionBatchTest {
    
    @TestSetup
    public static void createTestData(){
        BIS_Project_Import_Config__c bisConf = new BIS_Project_Import_Config__c(SetupOwnerId = UserInfo.getOrganizationId());
        bisConf.Deletion_Batch_Size__c = 350;
        bisConf.Deletion_Infobau_Month_Limit__c = 6;
        bisConf.Deletion_Ibau_Month_Limit__c = 12;
        insert bisConf;

        Date todayDate = Date.today();
        Date futureDate = Date.today().addMonths(1);
        Date sixMonthsLimit = Date.today().addMonths(-6);
        Date oneYearLimit = Date.today().addMonths(-12);

        Territory2 randomExistingTtr = [SELECT Id, Territory2TypeId, Territory2ModelId FROM Territory2 LIMIT 1];

        // ibau don't delete
        Project__c project1 = new Project__c();
        project1.Name = 'Test Project 1';
        project1.Project_Address__CountryCode__s = 'DE';
        project1.Project_Address__City__s = 'TestCity';
        project1.Project_Address__PostalCode__s = '12345';
        project1.Project_Address__Street__s = 'Test Street';
        project1.Core_Source_System__c = 'BIS';
        project1.Project_Source__c = '29';
        project1.Project_Construction_Progress__c = '7';
        project1.Exact_Source__c = 'iBau';
        project1.Project_Construction_End__c = oneYearLimit;
        project1.Active__c = true;
        insert project1;

        // infobau don't delete
        Project__c project2 = new Project__c();
        project2.Name = 'Test Project 2';
        project2.Project_Address__CountryCode__s = 'DE';
        project2.Project_Address__City__s = 'Test Town';
        project2.Project_Address__PostalCode__s = '99999';
        project2.Project_Address__Street__s = 'Test Street';
        project2.Core_Source_System__c = 'BIS';
        project2.Project_Source__c = '29';
        project2.Project_Construction_Progress__c = '7';
        project2.Exact_Source__c = 'infoBau';
        project2.Project_Construction_End__c = oneYearLimit;
        project2.Active__c = true;
        insert project2;

        // ibau Project delete
        Project__c project3 = new Project__c();
        project3.Name = 'Test Project 3';
        project3.Project_Address__CountryCode__s = 'DE';
        project3.Project_Address__City__s = 'TestCity';
        project3.Project_Address__PostalCode__s = '88888';
        project3.Project_Address__Street__s = 'Test Street';
        project3.Core_Source_System__c = 'BIS';
        project3.Project_Source__c = '29';
        project3.Project_Construction_Progress__c = '7';
        project3.Exact_Source__c = 'iBau';
        project3.Project_Construction_End__c = oneYearLimit;
        project3.Active__c = true;
        insert project3;

        // infobau Project delete
        Project__c project4 = new Project__c();
        project4.Name = 'Test Project 4';
        project4.Project_Address__CountryCode__s = 'DE';
        project4.Project_Address__City__s = 'Test Town';
        project4.Project_Address__PostalCode__s = '77777';
        project4.Project_Address__Street__s = 'Test Street';
        project4.Core_Source_System__c = 'BIS';
        project4.Project_Source__c = '29';
        project4.Project_Construction_Progress__c = '7';
        project4.Exact_Source__c = 'infoBau';
        project4.Project_Construction_End__c = oneYearLimit;
        project4.Active__c = true;
        insert project4;

        //infobau Project don't delete
        Project__c project5 = new Project__c();
        project5.Name = 'Test Project 5';
        project5.Project_Address__CountryCode__s = 'DE';
        project5.Project_Address__City__s = 'Test Town';
        project5.Project_Address__PostalCode__s = '77777';
        project5.Project_Address__Street__s = 'Test Street';
        project5.Core_Source_System__c = 'BIS';
        project5.Project_Source__c = '29';
        project5.Project_Construction_Progress__c = '7';
        project5.Exact_Source__c = 'infoBau';
        project5.Project_Construction_End__c = todayDate;
        project5.Active__c = true;
        insert project5;

        //ibau Project don't delete
        Project__c project6 = new Project__c();
        project6.Name = 'Test Project 6';
        project6.Project_Address__CountryCode__s = 'DE';
        project6.Project_Address__City__s = 'Test Town';
        project6.Project_Address__PostalCode__s = '77777';
        project6.Project_Address__Street__s = 'Test Street';
        project6.Core_Source_System__c = 'BIS';
        project6.Project_Source__c = '29';
        project6.Project_Construction_Progress__c = '7';
        project6.Exact_Source__c = 'iBau';
        project6.Project_Construction_End__c = futureDate;
        project6.Active__c = true;
        insert project6;

        Account acc = new Account(Name = 'Test Acc');
        acc.Save_without_Email__c = true;
        acc.BillingCity = 'Test City';
        acc.BillingPostalCode = '12345';
        acc.BillingStreet = 'Test Street 1';
        insert acc;

        Contact con = new Contact();
        con.FirstName = 'Deletion';
        con.LastName = 'Test 1';
        con.AccountId = acc.Id;
        con.MobilePhone = '+49123456789';
        con.Salutation = 'Mr.';
        con.Email = 'testcon@accenture.com';
        insert con;

        Project_Account_Relation__c projAccRelation1 = new Project_Account_Relation__c();
        projAccRelation1.Account__c = acc.Id;
        projAccRelation1.Project__c = project1.Id;
        insert projAccRelation1;

        Project_Account_Relation__c projAccRelation2 = new Project_Account_Relation__c();
        projAccRelation2.Account__c = acc.Id;
        projAccRelation2.Project__c = project2.Id;
        insert projAccRelation2;

        Project_Contact_Relation__c projConRelation1 = new Project_Contact_Relation__c();
        projConRelation1.Contact__c = con.Id;
        projConRelation1.Project__c = project1.Id;
        insert projConRelation1;

        Opportunity opp1 = new Opportunity();
        opp1.Name = 'Test Opp';
        opp1.StageName = 'New';
        opp1.CloseDate = todayDate;
        opp1.Project__c = project1.Id;
        opp1.Construction_Site_Address__CountryCode__s = 'DE';
        opp1.Construction_Site_Address__City__s = 'TestCity';
        opp1.Construction_Site_Address__PostalCode__s = '55555';
        opp1.Construction_Site_Address__Street__s = 'Test Street';
        insert opp1;
      
        Order__c order1 = new Order__c();
        order1.Project__c = project1.Id;
        insert order1;

        Order__c order2 = new Order__c();
        order2.Project__c = project2.Id;
        insert order2;

        Task task1 = new Task();
        task1.WhatId = project1.Id;
        insert task1;
    }

    @IsTest
    public static void test_deleteIbauProjects() {
        assertIBauProjects(3);

        Test.startTest();
            Database.executeBatch(new BISProjectDeletionBatch(), 350);
        Test.stopTest();

        assertIBauProjects(2);
    }

    @IsTest
    public static void test_deleteInfobauProjects() {
        assertInfoBauProjects(3);

        Test.startTest();
            Database.executeBatch(new BISProjectDeletionBatch(), 350);
        Test.stopTest();

        assertInfoBauProjects(2);
    }

    @IsTest
    public static void test_deactivateProjects() {
        assertInactiveProjects(0);

        Test.startTest();
            Database.executeBatch(new BISProjectDeletionBatch(), 350);
        Test.stopTest();

        assertInactiveProjects(3);
    }

    @IsTest
    public static void BISProjectDeletionBatchScheduler() {
        Test.startTest();
        
		String CRON_EXP = '0 0 0 3 9 ? 2080';
		String jobId = System.schedule('testScheduledApex', CRON_EXP, new BISProjectDeletionBatchScheduler());
        List<CronTrigger> ctList = [SELECT id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE Id = :jobId];
        
        Test.stopTest();
        
        System.assert(!ctList.isEmpty());
    }

    public static void assertIBauProjects(Integer count){
        System.debug([SELECT Id, Exact_Source__c FROM Project__c]);
        List<Project__c> projectList = [SELECT Id FROM Project__c WHERE Exact_Source__c = 'iBau'];
        System.assertEquals(count,projectList.size());
    }

    public static void assertInfoBauProjects(Integer count){
        List<Project__c> projectList = [SELECT Id FROM Project__c WHERE Exact_Source__c = 'infoBau'];
        System.assertEquals(count,projectList.size());
    }

    public static void assertInactiveProjects(Integer count){
        List<Project__c> projectList = [SELECT Id FROM Project__c WHERE Core_Source_System__c = 'BIS' AND Active__c = false];
        System.assertEquals(count,projectList.size());
    }

}