/**
 * Test class for "BISProjectImport".
 * 
 * @author	rene.pienkoss@accenture.com
 *
 * @version 2022-01-20	rene.pienkoss@accenture.com		creation
 * @version 2023-09-08  miriam.ida.tyroller@accenture   added testing for involved accounts
 * @version 2023-10-30  isabella.moos@accenture         modify test methods for new projekt account (lead) relations, as they cannot be tested in this context due to chained queueable jobs limit in test classes
 */
@IsTest(SeeAllData=false)
public with sharing class BISProjectImportTest {

    public final static String IBAU_ID_TESTING = '123';
    public final static String INFOBAU_ID_TESTING = '345';
    public final static String INFOBAU_DOUBLE_ID_TESTING = '999';
    public final static String IBAU_DOUBLE_ID_TESTING = '888';
    
    /**
     * Create test data
     */
    @TestSetup
    public static void createTestData() {
        // create custom setting
        BIS_Project_Import_Config__c bisConf = new BIS_Project_Import_Config__c(SetupOwnerId = UserInfo.getOrganizationId());
        bisConf.Page_Size__c = 100;
        bisConf.Filter_JSON_Ibau_DE__c = '{"project$$attributes$$town": "Düsseldorf"}';
        bisConf.Filter_JSON_Infobau__c = '{"project$$attributes$$town": "Weiden"}';
        bisConf.Error_Emails__c = 'miriam.ida.tyroller@accenture.com';
        bisConf.Project_Construction_Start_Placeholder__c = '1999-09-09T23:00:00.000Z';
        bisConf.Include_Involved_Accounts__c = true;
        insert bisConf;

        Id rt_Propect = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('ZR_Standard_Account_Prospect').getRecordTypeId();
        Account acc1 = new Account(Name = 'ACN Test Account BIS Import 1');
        acc1.RecordTypeId = rt_Propect;
        acc1.Phone = '+4911223344';
        acc1.Customer_Relation__c = 'Customer';
        acc1.Core_Email__c = 'testacc@BISImport.com';
        acc1.BillingStreet = 'Test Street 1';
        acc1.BillingCity = 'Jena';
        acc1.BillingPostalCode = '07745';
        acc1.BillingCountryCode = 'DE';
        acc1.Infobau_Id__c = INFOBAU_ID_TESTING;
        acc1.Ibau_Id__c = IBAU_ID_TESTING;
        insert acc1;

        Account acc2 = new Account(Name = 'ACN Test Account BIS Import 2');
        acc2.RecordTypeId = rt_Propect;
        acc2.Phone = '+4998765498';
        acc2.Customer_Relation__c = 'Customer';
        acc2.Core_Email__c = 'testacc@test.com';
        acc2.BillingStreet = 'Test Street 9';
        acc2.BillingCity = 'City';
        acc2.BillingPostalCode = '12345';
        acc2.BillingCountryCode = 'DE';
        acc2.Infobau_Id__c = INFOBAU_DOUBLE_ID_TESTING;
        acc2.Ibau_Id__c = IBAU_DOUBLE_ID_TESTING;
        insert acc2;

        Account acc3 = new Account(Name = 'ACN Test Account BIS Import 3');
        acc3.RecordTypeId = rt_Propect;
        acc3.Phone = '+4956789677';
        acc3.Customer_Relation__c = 'Customer';
        acc3.Core_Email__c = 'testacc@mail.com';
        acc3.BillingStreet = 'Test Street 3';
        acc3.BillingCity = 'Town';
        acc3.BillingPostalCode = '54321';
        acc3.BillingCountryCode = 'DE';
        acc3.Infobau_Id__c = INFOBAU_DOUBLE_ID_TESTING;
        acc3.Ibau_Id__c = IBAU_DOUBLE_ID_TESTING;
        insert acc3;
    }

    /**
     * test_projectImport_ibau_de
     */
    @IsTest
    public static void test_projectImport_ibau_de() {
        String context = BISProjectImport.CONTEXT_IBAU_DE;

        // ensure that timestamp of last update is null
        BIS_Project_Import_Config__c conf = BIS_Project_Import_Config__c.getOrgDefaults();
        Decimal lastImportTimestamp = (Decimal) conf.get(BISProjectImport.timestampFieldNamesByContext.get(context));
        System.assertEquals(null, lastImportTimestamp);

        Test.startTest();

        BISProjectImport projectImport = new BISProjectImport(context);
        System.enqueueJob(projectImport);
        
        Test.stopTest();

        // validate results
        // check if project records has been created
        List<Project__c> proList = [SELECT Id, Exact_Source__c, External_ID__c FROM Project__c];
        System.assertEquals(1, proList.size());
        System.assertEquals('iBau', proList[0].Exact_Source__c);
        System.assertEquals('ibau_1714447', proList[0].External_ID__c);

        //assert involved Accounts relations were created successfully
        assertAccountLeads(1);
        //assertProjectAccountRelations(3);
        //assertProjectAccountLeadRelations(1);
        //assertDoubleIbauProjectAccountRelations(2,IBAU_DOUBLE_ID_TESTING);

        // check if timestamp of last update is updated
        conf = BIS_Project_Import_Config__c.getOrgDefaults();
        lastImportTimestamp = (Decimal) conf.get(BISProjectImport.timestampFieldNamesByContext.get(context));
        System.assertNotEquals(null, lastImportTimestamp);
    }

    /**
     * test_projectImport_ibau_de_error
     */
    @IsTest
    public static void test_projectImport_ibau_de_error() {
        Test.startTest();

        BISProjectImport projectImport = new BISProjectImport(BISProjectImport.CONTEXT_IBAU_DE);
        projectImport.testError = true;
        System.enqueueJob(projectImport);
        
        Test.stopTest();

        // validate results
        List<Project__c> proList = [SELECT Id, Exact_Source__c, External_ID__c FROM Project__c];
        List<Core_Error_Log__c> errorLogs = [SELECT Id, Core_Apex_Class__c FROM Core_Error_Log__c WHERE Core_Apex_Class__c = : BISProjectImport.CLASSNAME];
        
        System.assertEquals(0, proList.size());
        System.assertEquals(1, errorLogs.size());
    }

    /**
     * test_projectImport_ibau_de_retry
     */
    @IsTest
    public static void test_projectImport_ibau_de_retry() {
        Test.startTest();

        BISProjectImport projectImport = new BISProjectImport(BISProjectImport.CONTEXT_IBAU_DE);
        projectImport.testRetry = true;
        System.enqueueJob(projectImport);
        
        Test.stopTest();

        // validate results
        List<Core_Error_Log__c> errorLogs = [SELECT Id, Core_Apex_Class__c FROM Core_Error_Log__c WHERE Core_Apex_Class__c = : BISProjectImport.CLASSNAME];
        System.assertEquals(0, errorLogs.size());
    }

    /**
     * test_projectImport_infobau
     */
    @IsTest
    public static void test_projectImport_infobau() {
        String context = BISProjectImport.CONTEXT_INFOBAU;

        // ensure that timestamp of last update is null
        BIS_Project_Import_Config__c conf = BIS_Project_Import_Config__c.getOrgDefaults();
        Decimal lastImportTimestamp = (Decimal) conf.get(BISProjectImport.timestampFieldNamesByContext.get(context));
        System.assertEquals(null, lastImportTimestamp);

        Test.startTest();

        BISProjectImport projectImport = new BISProjectImport(context);
        System.enqueueJob(projectImport);
        
        Test.stopTest();

        // validate results
        // check if project records has been created
        List<Project__c> proList = [SELECT Id, Exact_Source__c, External_ID__c, Project_Construction_Start__c, Project_Construction_End__c,
                                        (SELECT Id, External_ID__c, Winner__c FROM Submission_Results__r) 
                                    FROM Project__c];
        System.assertEquals(1, proList.size());
        System.assertEquals('infoBau', proList[0].Exact_Source__c);
        System.assertEquals('infobau_12345', proList[0].External_ID__c);

        // submission results
        System.assertEquals(4, proList[0].Submission_Results__r.size());
        for (Submission_Result__c sr : proList[0].Submission_Results__r) {
            System.debug('sr.External_ID__c: ' + sr.External_ID__c);
            if (sr.External_ID__c == proList[0].External_ID__c+'_6000210') {
                System.assertEquals(true, sr.Winner__c);
            }
            else {
                System.assertEquals(false, sr.Winner__c);
            }
        }

        //assert involved Accounts relations were created successfully
        assertAccountLeads(2);
        //assertProjectAccountRelations(3);
        //assertProjectAccountLeadRelations(2);
        //assertDoubleInfobauProjectAccountRelations(2,INFOBAU_DOUBLE_ID_TESTING);


        // check if timestamp of last update is updated
        conf = BIS_Project_Import_Config__c.getOrgDefaults();
        lastImportTimestamp = (Decimal) conf.get(BISProjectImport.timestampFieldNamesByContext.get(context));
        System.assertNotEquals(null, lastImportTimestamp);
    }

    /**
     * test_projectImport_infobau_error
     */
    @IsTest
    public static void test_projectImport_infobau_error() {
        Test.startTest();

        BISProjectImport projectImport = new BISProjectImport(BISProjectImport.CONTEXT_INFOBAU);
        projectImport.testError = true;
        System.enqueueJob(projectImport);
        
        Test.stopTest();

        // validate results
        List<Project__c> proList = [SELECT Id, Exact_Source__c, External_ID__c, 
                                        (SELECT Id, External_ID__c, Winner__c FROM Submission_Results__r) 
                                    FROM Project__c];
        List<Core_Error_Log__c> errorLogs = [SELECT Id, Core_Apex_Class__c, Core_Error_Message__c,Core_Exception_Type__c, Core_Stack_Trace__c, Core_Technical_Error_Message__c FROM Core_Error_Log__c WHERE Core_Apex_Class__c = : BISProjectImport.CLASSNAME];

        System.assertEquals(1, proList.size());
        System.assertEquals(1, errorLogs.size());
    }

    /**
     * test_projectImport_errorlog
     */
    @IsTest
    public static void test_projectImport_errorlog() {
        Test.startTest();

        BISProjectImport projectImport = new BISProjectImport(BISProjectImport.CONTEXT_INFOBAU);
        projectImport.createErrorLog('Test Error');
        
        Test.stopTest();

        // validate results
        System.assertEquals(1, projectImport.errorLogs.size());
    }

    /**
     * test_BISIbauImportScheduler
     */
    @IsTest
    public static void test_BISIbauImportScheduler() {
        Test.startTest();
        
		// Schedule the test job
		String CRON_EXP = '0 0 0 3 9 ? 2080';
		String jobId = System.schedule('testBasicScheduledApex', CRON_EXP, new BISIbauImportScheduler());
		// Get the information from the CronTrigger API object
        List<CronTrigger> ctList = [SELECT id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE Id = :jobId];
        
        Test.stopTest();
        
        // validate results
        System.assert(!ctList.isEmpty());
    }

    /**
     * test_BISInfobauImportScheduler
     */
    @IsTest
    public static void test_BISInfobauImportScheduler() {
        Test.startTest();
        
		// Schedule the test job
		String CRON_EXP = '0 0 0 3 9 ? 2080';
		String jobId = System.schedule('testBasicScheduledApex', CRON_EXP, new BISInfobauImportScheduler());
		// Get the information from the CronTrigger API object
        List<CronTrigger> ctList = [SELECT id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE Id = :jobId];
        
        Test.stopTest();
        
        // validate results
        System.assert(!ctList.isEmpty());
    }

    

    public static void assertAccountLeads(Integer count){
        List<Account_Lead__c> accountLeadList = [SELECT Id FROM Account_Lead__c];
        System.assertEquals(count,accountLeadList.size());
    }

    public static void assertProjectAccountRelations(Integer count){
        List<Project_Account_Relation__c> projAccRelationList = [SELECT Id FROM Project_Account_Relation__c];
        System.assertEquals(count,projAccRelationList.size());
    }

    public static void assertDoubleInfobauProjectAccountRelations(Integer count, String InfobauID){
        List<Project_Account_Relation__c> projAccRelationList = [SELECT Id, Account__r.Infobau_Id__c FROM Project_Account_Relation__c WHERE Account__r.Infobau_Id__c = : InfobauID];
        System.assertEquals(count,projAccRelationList.size());
    }

    public static void assertDoubleIbauProjectAccountRelations(Integer count, String IbauID){
        List<Project_Account_Relation__c> projAccRelationList = [SELECT Id, Account__r.Ibau_Id__c FROM Project_Account_Relation__c WHERE Account__r.Ibau_Id__c = : IbauID];
        System.assertEquals(count,projAccRelationList.size());
    }

    public static void assertProjectAccountLeadRelations(Integer count){
        List<Project_Account_Lead_Relation__c> projAccLeadRelationList = [SELECT Id FROM Project_Account_Lead_Relation__c];
        System.assertEquals(count,projAccLeadRelationList.size());
    }

}