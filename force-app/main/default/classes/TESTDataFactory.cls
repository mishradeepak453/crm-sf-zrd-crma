/**
 * Test data factory providing methods to create data for test classes
 *
 * @author  isabella.moos@accenture.com
 *
 * @version 2023-10-20  isabella.moos@accenture.com     creation
 */
@isTest
public class TESTDataFactory {
    /**
     * Return List<Account> of test accounts 
     *
     * @param numOfRecords          number of records to be returned
     * @param recordTypeDevName     record type developer name
     * @param doInsert              insert the created records into database
     *
     * @return List<Account>
     */
    public static List<Account> createTestAccounts(Integer numOfRecords, String recordTypeDevName, Boolean doInsert) {
        List<Account> testAccountList = new List<Account>();
        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(recordTypeDevName).getRecordTypeId();

        for(Integer i = 0; i < numOfRecords; i++) {
            Account testAccount = new Account(
                Name = 'ACN Test Account' + i,
                RecordTypeId = recordTypeId,
                Phone = '+49123456780',
                Customer_Relation__c = 'Customer',
                Core_Email__c = 'testacc@accenture.com',
                BillingStreet = 'Test Street ' + i,
                BillingCity = 'Jena',
                BillingPostalCode = '07745',
                BillingCountryCode = 'DE'
            );
            testAccountList.add(testAccount);
        }

        if (doInsert) {
            insert testAccountList;
        }

        return testAccountList;
    }

    /**
     * Return List<Account_Lead__c> of test account leads 
     *
     * @param numOfRecords          number of records to be returned
     * @param recordTypeDevName     record type developer name
     * @param doInsert              insert the created records into database
     *
     * @return List<Account_Lead__c>
     */
    public static List<Account_Lead__c> createTestAccountLeads(Integer numOfRecords, String recordTypeDevName, Boolean doInsert) {
        List<Account_Lead__c> testAccountLeadList = new List<Account_Lead__c>();
        Id recordTypeId = Schema.SObjectType.Account_Lead__c.getRecordTypeInfosByDeveloperName().get(recordTypeDevName).getRecordTypeId();

        for(Integer i = 0; i < numOfRecords; i++) {
            Account_Lead__c testAccountLead = new Account_Lead__c(
                Name = 'ACN Test Account Lead' + i,
                RecordTypeId = recordTypeId,
                Phone__c = '+49123456780',
                Email__c = 'testacc@accenture.com',
                Address__Street__s = 'Test Street ' + i,
                Address__City__s = 'Jena',
                Address__PostalCode__s = '07745',
                Address__CountryCode__s = 'DE'
            );
            testAccountLeadList.add(testAccountLead);
        }

        if (doInsert) {
            insert testAccountLeadList;
        }

        return testAccountLeadList;
    }

    /**
     * Return List<Project__c> of test projectss 
     *
     * @param numOfRecords          number of records to be returned
     * @param recordTypeDevName     record type developer name
     * @param doInsert              insert the created records into database
     *
     * @return List<Project__c>
     */
    public static List<Project__c> createTestIBauProjects(Integer numOfRecords, String recordTypeDevName, Boolean doInsert) {
        List<Project__c> testProjectList = new List<Project__c>();
        Id recordTypeId = Schema.SObjectType.Project__c.getRecordTypeInfosByDeveloperName().get(recordTypeDevName).getRecordTypeId();

        for(Integer i = 0; i < numOfRecords; i++) {
            Project__c testProject = new Project__c(
                Name = 'Test Ibau Project ' + i,
                RecordTypeId = recordTypeId,
                Project_Address__CountryCode__s = 'DE',
                Project_Address__City__s = 'TestCity',
                Project_Address__PostalCode__s = '12345',
                Project_Address__Street__s = 'Test Street 1',
                Street_cleaned__c = 'test',
                House_Number_cleaned__c = '1',
                Core_Source_System__c = 'BIS',
                Project_Source__c = '29',
                Project_Construction_Progress__c = '7',
                Exact_Source__c = 'iBau',
                Project_Construction_End__c = Date.today().addMonths(-12),
                Active__c = true
            );
            testProjectList.add(testProject);
        }

        if (doInsert) {
            insert testProjectList;
        }

        return testProjectList;
    }

    /**
     * Return List<Project_Account_Relation__c> of test Project Account Relations 
     *
     * @param numOfRecords      number of records to be returned
     * @param relatedAccount    account record that will be linked to new Project_Account_Relation__c records
     * @param accountRole       role of account linked to new Project_Account_Relation__c records
     * @param relatedProject    project record that will be linked to new Project_Account_Relation__c records
     * @param doInsert          insert the created records into database
     *
     * @return List<Project__c>
     */
    public static List<Project_Account_Relation__c> createTestPARs(Integer numOfRecords, Account relatedAccount, String accountRole, Project__c relatedProject, Boolean doInsert) {
        List<Project_Account_Relation__c> testPARList = new List<Project_Account_Relation__c>();

        for(Integer i = 0; i < numOfRecords; i++) {
            Project_Account_Relation__c testPAR = new Project_Account_Relation__c(
                Account__c = relatedAccount.Id,
                Account_Role__c = accountRole,
                Project__c = relatedProject.Id
            );
            testPARList.add(testPAR);
        }

        if (doInsert) {
            insert testPARList;
        }

        return testPARList;
    }

    /**
     * Return List<Project_Account_Lead_Relation__c> of test Project Account Relations 
     *
     * @param numOfRecords          number of records to be returned
     * @param relatedAccountLead    account record that will be linked to new Project_Account_Lead_Relation__c records
     * @param accountRole           role of account linked to new Project_Account_Lead_Relation__c records
     * @param relatedProject        project record that will be linked to new Project_Account_Lead_Relation__c records
     * @param doInsert              insert the created records into database
     *
     * @return List<Project__c>
     */
    public static List<Project_Account_Lead_Relation__c> createTestPALRs(Integer numOfRecords, Account_Lead__c relatedAccountLead, String accountRole, Project__c relatedProject, Boolean doInsert) {
        List<Project_Account_Lead_Relation__c> testPALRList = new List<Project_Account_Lead_Relation__c>();

        for(Integer i = 0; i < numOfRecords; i++) {
            Project_Account_Lead_Relation__c testPALR = new Project_Account_Lead_Relation__c(
                Account_Lead__c = relatedAccountLead.Id,
                Account_Role__c = accountRole,
                Project__c = relatedProject.Id
            );
            testPALRList.add(testPALR);
        }

        if (doInsert) {
            insert testPALRList;
        }

        return testPALRList;
    }
}