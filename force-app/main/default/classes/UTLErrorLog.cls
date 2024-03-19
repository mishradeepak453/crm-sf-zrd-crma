/**
 * Util class to create and handle error log records (Core_Error_Log__c).
 * 
 * @author  rene.pienkoss@accenture.com
 * 
 * @version 2021-11-01  rene.pienkoss@accenture.com     creation
 */
public class UTLErrorLog {

    /**
     * Create error log record for Salesforce errors.
     * 
     * @param className
     * @param ex
     * @param customErrorMessage
     * @param errorRecordId
     * 
     * @return CoreError_Log__c record
     */
    public static Core_Error_Log__c createErrorLogRecord(String className, Exception ex, String customErrorMessage, String errorRecordId) {
        return createErrorLogRecord(className, ex, customErrorMessage, errorRecordId, null, false);
    }

    /**
     * Create error log record for Salesforce errors.
     * 
     * @param className
     * @param ex
     * @param customErrorMessage
     * @param ErrorRecordId
     * @param sourceSystem
     * @param integrationError
     * 
     * @return CoreError_Log__c record
     */
    public static Core_Error_Log__c createErrorLogRecord(String className, Exception ex, String customErrorMessage, String errorRecordId, String sourceSystem, Boolean integrationError) {
        return createErrorLogRecord(className, ex, customErrorMessage, errorRecordId, null, false, null, null);
    }

    /**
     * Create error log record for Integration errors.
     * 
     * @param className
     * @param ex
     * @param customErrorMessage
     * @param errorRecordId
     * @param sourceSystem
     * @param integrationError
     * @param externalSystemId
     * @param technicalErrorMessage
     * 
     * @return CoreError_Log__c record
     */
    public static Core_Error_Log__c createErrorLogRecord(String className, Exception ex, String customErrorMessage, String errorRecordId, String sourceSystem, Boolean integrationError, String externalSystemId, String technicalErrorMessage) {
        Core_Error_Log__c errorLog = new Core_Error_Log__c();
        errorLog.Core_Apex_Class__c = className;
        errorLog.Core_Process_User__c = UserInfo.getUserId();
        errorLog.Core_Salesforce_Id__c = errorRecordId;
        errorLog.Core_Error_Message__c = customErrorMessage.left(255);
        errorLog.Core_External_System_Id__c = externalSystemId;
        errorLog.Core_Technical_Error_Message__c = technicalErrorMessage;

        if (String.isNotBlank(sourceSystem)) {
            errorLog.Core_Source_System__c = sourceSystem;
        }

        if (ex != null) {
            errorLog.Core_Code_Line__c = ex.getLineNumber();
            errorLog.Core_Technical_Error_Message__c = ex.getMessage();
            errorLog.Core_Exception_Type__c = ex.getTypeName();
            errorLog.Core_Integration_Error__c = integrationError;
            errorLog.Core_Stack_Trace__c = ex.getStackTraceString();
        }

        Blob targetBlob = Blob.valueOf(errorLog.Core_Salesforce_Id__c +
                                        errorLog.Core_External_System_Id__c +
                                        errorLog.Core_Source_System__c +
                                        errorLog.Core_Apex_Class__c +
                                        errorLog.Core_Error_Message__c +
                                        errorLog.Core_Technical_Error_Message__c);
        Blob md5hash = Crypto.generateDigest('MD5', targetBlob);
        errorLog.Core_Checksum__c = EncodingUtil.convertToHex(md5hash);

        return errorLog;
    }

    /**
     * Obsolete insert method used until all references are replaced, directs immediately to upsert method
     * 
     * @param errorLogs
     * @param context
     * 
     * @return Boolean 
     */
    public static Boolean insertErrorLogs(List<Core_Error_Log__c> errorLogs, String context) {
        return upsertErrorLogs(errorLogs, null, context);
    }

    /**
     * Upsert passed error log records based on Core_Checksum__c field
     * 
     * @param errorLogs
     * @param errorList
     * @param context
     * 
     * @return Boolean isSuccess
     */
    public static Boolean upsertErrorLogs(List<Core_Error_Log__c> errorLogs, List<Exception> errorList, String context) {
        Boolean isSuccess = false;

        if (errorLogs != null && !errorLogs.isEmpty()) {
            System.debug('########## RP errorLogs: ' + errorLogs.size());
            Database.UpsertResult[] errorLogUpsertResult = Database.upsert(errorLogs, Core_Error_Log__c.Core_Checksum__c,false);
            List<Core_Error_Log__c> failedErrorLogUpserts = new List<Core_Error_Log__c>();

            for (Database.UpsertResult sr : errorLogUpsertResult) {
                if ( ! sr.isSuccess()) {
                    String errorMessage = 'Error while upserting error logs';

                    if (String.isNotBlank(context)) {
                        errorMessage += ' for: ' + context;
                    }
                    String recId = sr.getId();
                    String exceptionMessage = sr.getErrors()[0].getStatusCode() + ': ' + sr.getErrors()[0].getMessage();
                    System.debug('########## RP exceptionMessage: ' + exceptionMessage);

                    Core_Error_Log__c errLog = createErrorLogRecord('UTLErrorLog', new UTLErrorLogException(exceptionMessage), errorMessage, recId);
                    failedErrorLogUpserts.add(errLog);
                }
                else{
                    isSuccess = true;
                }
            }

            if (!failedErrorLogUpserts.isEmpty()) {
                Database.UpsertResult[] errorLogUpsertResults = Database.upsert(failedErrorLogUpserts, Core_Error_Log__c.Core_Checksum__c,false);
            }
        }
        
        return isSuccess;
    }

    /**
     * Create error emails out of Exceptions.
     * 
     * @param exList
     * @param developmentName
     * @param errorEmailAdresses
     */
    public static void prepareAndSendErrorEmail(List<Exception> exList, String developmentName, Set<String> errorEmailAddresses) {
        System.debug('########## RP prepareAndSendErrorEmail: ' + exList.size());

        if (exList != null && (!exList.isEmpty() || Test.isRunningTest())) {
            List<Core_Error_Log__c> errorLogs = new List<Core_Error_Log__c>();
            for (Exception ex : exList) {
                errorLogs.add(new Core_Error_Log__c(Core_Code_Line__c = ex.getLineNumber(), Core_Technical_Error_Message__c = ex.getMessage()));
            }

            prepareAndSendErrorEmail(errorLogs, developmentName, errorEmailAddresses);
        }
    }

    /**
     * Create error emails out of Core_Error_Log__c.
     * 
     * @param errorLogs
     * @param developmentName
     * @param errorEmailAddresses
     */
    public static void prepareAndSendErrorEmail(List<Core_Error_Log__c> errorLogs, String developmentName, Set<String> errorEmailAddresses) {
        System.debug('########## RP prepareAndSendErrorEmail');

        if (errorLogs != null && (!errorLogs.isEmpty() || Test.isRunningTest())) {
            System.debug('########## RP errorLogs: ' + errorLogs.size());
            // Specify the text content of the email.
            String errorText = Label.Error_Email_Text + ' \n\n';
            errorText += 'User/Organization: ' + UserInfo.getUserId() + '/' + UserInfo.getOrganizationId() + ' (' + System.Userinfo.getOrganizationName() + ')' + '\n\n';

            for (Core_Error_Log__c log : errorLogs) {
                String errorMessage = log.Core_Technical_Error_Message__c;
                if (String.isBlank(errorMessage)) {
                    errorMessage = log.Core_Error_Message__c;
                }
                errorText += '\n\nLine: ' + log.Core_Code_Line__c + ' - ' + errorMessage;
            }

            // send email
            if (errorEmailAddresses != null && !errorEmailAddresses.isEmpty()) {
                System.debug('########## RP errorEmailAddresses: ' + errorEmailAddresses.size());
                sendEmailNotification(Label.Error_Email_Subject + ' ' + developmentName, errorText, new List<String>(errorEmailAddresses));
            }
        }
    }

    /**
     * This method is used to send an Email notification about errors to the specified Email address.
     * 
     * @param subject
     * @param textString
     * @param emailAddresses
     */
    public static void sendEmailNotification(String subject, String textString, List<String> emailAddresses) {
        System.debug('########## RP sendEmailNotification');

        // Create a new single email message object
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

        // Strings to hold the email addresses to which you are sending the email.
        //String[] toAddresses = new String[] {emailAddress};
        String[] toAddresses = emailAddresses;

        // Assign the addresses for the To and CC lists to the mail object.
        mail.setToAddresses(toAddresses);
        //mail.setCcAddresses(ccAddresses);

        // Get OrgWideEmailAddress
        // OrgWideEmailAddress
        /*
        List<OrgWideEmailAddress> orgDefault = [SELECT Id FROM OrgWideEmailAddress WHERE IsAllowAllProfiles = true LIMIT 1];
        if ( ! orgDefault.isEmpty()) {
            mail.setOrgWideEmailAddressId(orgDefault[0].Id);
        }
        else {*/
        // Specify the name used as the display name.
        mail.setSenderDisplayName(Label.Error_Email_Sender);
        //}

        // Specify the subject line for your email address.
        mail.setSubject(subject);

        // Specify the text content of the email.
        mail.setPlainTextBody(textString);

        // Send the email you have created.
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{
                mail
        });
    }
 
    public class UTLErrorLogException extends Exception {}
}