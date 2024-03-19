/**
 * Test class for "ORGReportLimits".
 * 
 * @author	rene.pienkoss@accenture.com
 * 
 * @version 2022-05-30  rene.pienkoss@accenture.com     creation
 */
@IsTest(SeeAllData=false)
public with sharing class ORGReportLimitsTest {

    /**
     * Test logic
     */
    @IsTest
    public static void test_detectLimits() {
        // ensure that no limit records exists
        List<System_Limit__c> sysLimitsBefore = [SELECT Id FROM System_Limit__c];
        System.assertEquals(0, sysLimitsBefore.size());

        Test.startTest();

        ORGReportLimits orgLimitsJob = new ORGReportLimits();
        orgLimitsJob.detectLimits();
        
        Test.stopTest();

        // validate results
        List<System_Limit__c> sysLimitsAfter = [SELECT Id FROM System_Limit__c];
        System.assert(sysLimitsAfter.size() > 0);
    }

    /**
     * Test scheduler
     */
    @IsTest
    public static void test_execute() {
        Test.startTest();
        
		// Schedule the test job
		String CRON_EXP = '0 0 0 3 9 ? 2099';
		String jobId = System.schedule('testBasicScheduledApex', CRON_EXP, new ORGReportLimits());
		// Get the information from the CronTrigger API object
        List<CronTrigger> ctList = [SELECT id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE Id = :jobId];
        
        Test.stopTest();
        
        // validate results
        System.assert( ! ctList.isEmpty());
    }
}