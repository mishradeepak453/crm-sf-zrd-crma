/**
 * Test class for "AccountContactRelationTrigger".
 * 
 * @author	rene.pienkoss@accenture.com
 *
 * @version 2021-12-08	rene.pienkoss@accenture.com		creation
 */
@IsTest
private with sharing class AccountContactRelationTest {
    
    private static Account acc1;
    private static Account acc2;
    private static List<Contact> conList;
    private static List<AccountContactRelation> acrList;

    @TestSetup
    private static void init() {
        // Required for PostalCode-Mapping with callout
        GRACE_API_Config__c graceConfig = new GRACE_API_Config__c(SetupOwnerId = UserInfo.getOrganizationId());
        graceConfig.Api_Key__c = '123456789';
        insert graceConfig;
    }

    /**
     * Create test data
     */
    public static void createTestData() {
        // Account
        List<Account> accList = new List<Account>();

        Id rt_Propect = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('ZR_Standard_Account_Prospect').getRecordTypeId();
        acc1 = new Account(Name = 'ACN Test Account 1');
        acc1.RecordTypeId = rt_Propect;
        acc1.Phone = '+49123456780';
        acc1.Customer_Relation__c = 'Customer';
        acc1.Core_Email__c = 'testacc@accenture.com';
        acc1.BillingStreet = 'Test Street 1';
        acc1.BillingCity = 'Jena';
        acc1.BillingPostalCode = '07745';
        acc1.BillingCountryCode = 'DE';
        accList.add(acc1);

        acc2 = new Account(Name = 'ACN Test Account 2');
        acc2.RecordTypeId = rt_Propect;
        acc2.Phone = '+49123456781';
        acc2.Customer_Relation__c = 'Customer';
        acc2.Core_Email__c = 'testacc@accenture.com';
        acc2.BillingStreet = 'Test Street 24';
        acc2.BillingCity = 'Jena';
        acc2.BillingPostalCode = '07743';
        acc2.BillingCountryCode = 'DE';
        accList.add(acc2);

        insert accList;

        // Contact
        conList = new List<Contact>();

        for (Integer i = 0; i < 10; i++) {
            Contact con = new Contact();
            con.FirstName = 'Deletion';
            con.LastName = 'Test ' + i;
            con.AccountId = acc1.Id;
            con.MobilePhone = '+49123456789';
            con.Salutation = 'Mr.';
            con.Email = 'testcon@accenture.com';

            conList.add(con);
        }

        insert conList;

        // AccountContactRelation
        acrList = new List<AccountContactRelation>();

        for (Contact con : conList) {
            AccountContactRelation acr = new AccountContactRelation();
            acr.AccountId = acc2.Id;
            acr.ContactId = con.Id;
            acr.Role__c = 'ARCH';

            acrList.add(acr);
        }

        insert acrList;
    }

    /**
     * test_preventDeletion_BeforeUpdate
     */
    @IsTest
    public static void test_preventDeletion_BeforeUpdate() {
        Test.setMock(HttpCalloutMock.class, UTLMockHttpResponse.builder()
                .body('[]') // first Call on Insert
                .next()
                .body('[]') // second Call same Insert Call
        );
        Test.startTest();
        createTestData();
        Test.stopTest(); // required for asyc test data creation

        Boolean deletionPrevented = false;

        try {
            delete acrList;
        }
        catch (Exception e) {
            deletionPrevented = true;
        }

        // validate results
        List<AccountContactRelation> acrListNew = [SELECT Id FROM AccountContactRelation WHERE Id IN :acrList];
        System.assertEquals(true, deletionPrevented);
        System.assertEquals(acrList.size(), acrListNew.size());
    }
}