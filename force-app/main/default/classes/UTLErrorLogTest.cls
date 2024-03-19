/**
 * Test class for "UTLErrorLog".
 * 
 * @author	rene.pienkoss@accenture.com
 *
 * @version 2022-01-21	rene.pienkoss@accenture.com		creation
 */
@IsTest(SeeAllData=false)
public with sharing class UTLErrorLogTest {

    public static final String CLASSNAME = 'UTLErrorLogTest';

    /**
     * test_createErrorLogRecord
     */
    @IsTest
    public static void test_createErrorLogRecord() {
        Test.startTest();

        String errorMessage = 'Test Error';
        Core_Error_Log__c errLog = UTLErrorLog.createErrorLogRecord(CLASSNAME, new DmlException(errorMessage), errorMessage, null);
        Boolean isSuccess = UTLErrorLog.insertErrorLogs(new List<Core_Error_Log__c>{errLog}, CLASSNAME);
        
        Test.stopTest();

        // validate results
        System.assertEquals(true, isSuccess);
        List<Core_Error_Log__c> errorLogs = [SELECT Id, Core_Apex_Class__c, Core_Error_Message__c FROM Core_Error_Log__c];
        System.assertEquals(1, errorLogs.size());
        System.assertEquals(CLASSNAME, errorLogs[0].Core_Apex_Class__c);
        System.assertEquals(errorMessage, errorLogs[0].Core_Error_Message__c);
    }

    @IsTest
    public static void test_upsertErrorLog() {
        Test.startTest();

        String errorMessage = 'Test Upsert';
        Core_Error_Log__c errLog = UTLErrorLog.createErrorLogRecord(CLASSNAME, new DmlException(errorMessage), errorMessage, null);
        Boolean isSuccess = UTLErrorLog.insertErrorLogs(new List<Core_Error_Log__c>{errLog}, CLASSNAME);
        System.assertEquals(true, isSuccess);
            isSuccess = UTLErrorLog.upsertErrorLogs(new List<Core_Error_Log__c>{errLog}, null, CLASSNAME);
        Test.stopTest();

        System.assertEquals(true, isSuccess);
        List<Core_Error_Log__c> errorLogs = [SELECT Id, Core_Apex_Class__c, Core_Error_Message__c FROM Core_Error_Log__c];
        System.assertEquals(1, errorLogs.size());
    }

    @IsTest
    public static void test_upsertErrorLog_failed() {
        Test.startTest();

        String errorMessage = 'Test Upsert Failed';
        Core_Error_Log__c errLog = UTLErrorLog.createErrorLogRecord(CLASSNAME, new DmlException(errorMessage), errorMessage, null);
        Boolean isSuccess = UTLErrorLog.insertErrorLogs(new List<Core_Error_Log__c>{errLog}, CLASSNAME);
        List<Core_Error_Log__c> errorLogsList = [SELECT Id, Core_Apex_Class__c, Core_Error_Message__c FROM Core_Error_Log__c];
        
        System.assertEquals(true, isSuccess);
            isSuccess = UTLErrorLog.upsertErrorLogs(errorLogsList, null, CLASSNAME);
        Test.stopTest();

        System.assertEquals(false, isSuccess);
        List<Core_Error_Log__c> errorLogs = [SELECT Id, Core_Apex_Class__c, Core_Error_Message__c FROM Core_Error_Log__c];
        System.assertEquals(2, errorLogs.size());
        Boolean utilErrorLogFound = false;
        for (Core_Error_Log__c el : errorLogs) {
            if (el.Core_Apex_Class__c == 'UTLErrorLog') {
                utilErrorLogFound = true;
                break;
            }
        }
        System.assertEquals(true, utilErrorLogFound);
    }

    /**
     * test_prepareAndSendErrorEmail
     */
    @IsTest
    public static void test_prepareAndSendErrorEmail() {
        Test.startTest();

        String errorMessage = 'Test Error';
        UTLErrorLog.prepareAndSendErrorEmail(new List<Exception>{new DmlException(errorMessage)}, CLASSNAME, new Set<String>{'testuser@accenture.com'});
        
        Test.stopTest();
    }
}