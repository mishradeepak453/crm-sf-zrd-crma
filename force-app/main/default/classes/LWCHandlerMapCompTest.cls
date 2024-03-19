/**
 * SF-1134:  test class for LWCHandlerMapComp
 * 
 * @author  miriam.ida.tyroller@accenture.com
 * 
 * @version 2023-10-09  miriam.ida.tyroller       creation
 */
@IsTest
public with sharing class LWCHandlerMapCompTest {
    
    @TestSetup
    public static void createTestData(){
        Date todayDate = Date.today();

        // ibau project with total volume
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
        project1.Project_Construction_Start__c = todayDate;
        project1.Total_Volume__c = 2000.00;
        project1.Active__c = true;
        insert project1;

        // infobau project with total volume
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
        project1.Project_Construction_Start__c = todayDate;
        project2.Total_Volume__c = 3000.00;
        project2.Active__c = true;
        insert project2;

        // ibau Project without total volume
        Project__c project3 = new Project__c();
        project3.Name = 'Test Project 3';
        project3.Project_Address__CountryCode__s = 'DE';
        project3.Project_Address__StateCode__s = 'BY';
        project3.Project_Address__City__s = 'TestCity';
        project3.Project_Address__PostalCode__s = '88888';
        project3.Project_Address__Street__s = 'Test Street';
        project3.Core_Source_System__c = 'BIS';
        project3.Project_Source__c = '29';
        project3.Project_Construction_Progress__c = '7';
        project3.Exact_Source__c = 'iBau';
        project1.Project_Construction_Start__c = todayDate;
        project3.Active__c = true;
        insert project3;


        Account acc1 = new Account(Name = 'Test Acc 1');
        acc1.Save_without_Email__c = true;
        acc1.BillingCity = 'Test Town';
        acc1.BillingPostalCode = '54321';
        acc1.BillingStreet = 'Test Street 3';
        insert acc1;

        Account acc2 = new Account(Name = 'Test Acc 2');
        acc2.Name2__c = 'Test Acc 2 Name 2';
        acc2.Save_without_Email__c = true;
        acc2.BillingCity = 'Test City';
        acc2.BillingPostalCode = '12345';
        acc2.BillingStateCode = 'BY';
        acc2.BillingStreet = 'Test Street 1';
        insert acc2;

        Account acc3 = new Account(Name = 'Test Acc 3');
        acc3.Save_without_Email__c = true;
        acc3.BillingCity = 'Test Test';
        acc3.BillingPostalCode = '99999';
        acc3.BillingStreet = 'Test Street 9';
        insert acc3;

    }

    @IsTest
    public static void test_queryMapDataProjects() {
        String listViewId = 'help';

        Test.startTest();
            List<LWCHandlerMapComp.MapMarker> projectList = LWCHandlerMapComp.queryMapData(listViewId, 'www.Project.de');
        Test.stopTest();

        System.assertEquals(3,projectList.size());
    }

    @IsTest
    public static void test_queryMapDataAccounts() {
        String listViewId = 'help';

        Test.startTest();
            List<LWCHandlerMapComp.MapMarker> accountList = LWCHandlerMapComp.queryMapData(listViewId, 'www.Account.de');
        Test.stopTest();

        System.assertEquals(3,accountList.size());
    }

    @IsTest
    public static void test_queryUserListViewsProjects() {

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        System.runAs (thisUser) {
            List<ListView> testList = [SELECT Id, Name FROM ListView WHERE SobjectType = 'Project__c'];

            Test.startTest();
                List<ListView> listViewList = LWCHandlerMapComp.queryUserListViews('www.Project.de');
            Test.stopTest();

        System.assertEquals(testList.size(),listViewList.size());

        }
    }

    @IsTest
    public static void test_queryUserListViewsAccounts() {

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        System.runAs (thisUser) {
            List<ListView> testList = [SELECT Id, Name FROM ListView WHERE SobjectType = 'Account'];
        

            Test.startTest();
                List<ListView> listViewList = LWCHandlerMapComp.queryUserListViews('www.Account.de');
            Test.stopTest();

        System.assertEquals(testList.size(),listViewList.size());
        }
    }

    

}