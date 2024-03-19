/**
 * SF-911 Account-Sync mittels Grace-Aufruf
 * The Service communicate Tests.
 *
 * @group GRSY - Grace Sync Account
 * @date 21.06.2022
 * @author daniel.gette@zepplin.com
 *
 * @version 2022-10-04	miriam.ida.tyroller@accenture.com
 */
@IsTest
private class GRSYAccServiceTest {

    private static final String MOCK_API_KEY = '123456789';
    public final static String SALESUNIT_ID_TESTING1 = 'M123';
    public final static String SALESUNIT_ID_TESTING2 = 'M345';

    private static final String ID_ACCOUNT1 = '1234567';
    private static final String ID_ACCOUNT2 = '7654321';
    private static final String ID_ACCOUNT3 = '9876543';
    private static final String NAME_TESTING1 = 'Gelb';
    private static final String NAME_TESTING2 = 'Rot';
    private static final String NAME_TESTING3 = 'Lila';
    private static final String ID_CONTACT1 = '12345';
    private static final String ID_CONTACT2 = '67890';
    private static final String ID_CONTACT3 = '98765';
    private static final String ID_CONTACT4 = '54321';
    private static final String ID_COMPANYGROUP = '123';
    private static final String ID_COMPANYKEY = '456';
    private static final String CORE_COMMERCIAL_ADMIN = 'ADMINX';

    private static Set<String> IDS_ACCOUNT;
    private static Set<String> IDS_CONTACT;

    @TestSetup
    public static void createTerritories() {
        // Query one existing Territory to reuse the needed attributes
        List<Territory2> randomExistingTTrs = [SELECT Id, Territory2TypeId, Territory2ModelId FROM Territory2 LIMIT 3];
        Id ttrTypeId = randomExistingTTrs[2].Territory2TypeId;
        Id ttrModelId = randomExistingTTrs[2].Territory2ModelId;
        Id ttrParentId = randomExistingTTrs[2].Id;

        Territory2 terr1 = new Territory2(
            AccountAccessLevel = 'Edit',
            CaseAccessLevel = 'None',
            DeveloperName = 'ZR_Mietstation_1',
            Name = 'ApexTestTerritory 1',
            Core_External_ID__c = SALESUNIT_ID_TESTING1,
            OpportunityAccessLevel = 'Edit',
            Territory2ModelId = ttrModelId,
            Territory2TypeId = ttrTypeId,
            ParentTerritory2Id = ttrParentId
        );
        insert terr1;

        Territory2 terr2 = new Territory2(
            AccountAccessLevel = 'Edit',
            CaseAccessLevel = 'None',
            DeveloperName = 'ZR_Mietstation_2',
            Name = 'ApexTestTerritory 2',
            Core_External_ID__c = SALESUNIT_ID_TESTING2,
            OpportunityAccessLevel = 'Edit',
            Territory2ModelId = ttrModelId,
            Territory2TypeId = ttrTypeId,
            ParentTerritory2Id = ttrParentId
        );
        insert terr2;
    }

    @isTest
    public static void test_1Account2Contacts(){

        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1};
        IDS_CONTACT = new Set<String>{ID_CONTACT1,ID_CONTACT2};

        String response =
                  '['
                  + '  {' 
                  +       '"Core_Customer_Number__c":"' + ID_ACCOUNT1 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING1 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Total_Checksum__c":"8888","Save_without_Email__c":true,'
                  +     '"Territory":' 
                  +     '['
                  +             '{"zip": "81241","businessarea": 1,"salesunitid": "' + TTRAccountHandlerTest.SALESUNIT_ID_TESTING1 + '","salesunit": "ApexTestTerritory 1","region": "0302","regionname": "07 Berlin/Brandenburg","businessareaname": "Maschinen- & Gerätevermietung"}'
                  +     '],'
                  +     '"Companygroup":' 
                  +     '[' 
                  +             '{"Account_Manager__c":"test123", "Company_Group_ID__c":' + ID_COMPANYGROUP + ', "Key_Account__c":true, "Large_Account__c":false, "Name":"testname", "Payment_Terms__c":"Z123"}'
                  +     '],'
                  +     '"Companykey":' 
                  +     '[' 
                  +             '{"Company_Group__c":' + ID_COMPANYGROUP + ', "Company_Key_ID__c":' + ID_COMPANYKEY + ', "Name":"Test GmbH", "Payment_Terms__c":"Z245"}'
                  +     '],'
                  +     '"Contacts":'
                  +       '[' 
                  +       '   {"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+4930127633","Salutation":"Mrs.","Save_without_Email__c":true},{"PersonID__c":"'+ ID_CONTACT2 + '","FirstName":"Bettina","LastName":"Test","Phone":"+4930127633","Salutation":"Mrs.","Title__c":"42","Save_without_Email__c":true}'
                  +       ']'
                  + '  }'
                  + ']';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processAccountList(IDS_ACCOUNT);
                Test.stopTest();
        }

        assertAccountContactRelationsExist(IDS_ACCOUNT, IDS_CONTACT, 2);
        assertContactTitle(ID_CONTACT1, null);
        assertObjectTerritory2Association(IDS_ACCOUNT, TTRAccountHandlerTest.SALESUNIT_ID_TESTING1, 1);
        assertCompanyGroup(ID_COMPANYGROUP, 1);
        assertCompanyKey(ID_COMPANYKEY, ID_COMPANYGROUP, 1);
    }

    @isTest
    public static void test_accountInvalidField(){

        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1};
        IDS_CONTACT = new Set<String>{ID_CONTACT1,ID_CONTACT2};

        String response =
                  '['
                  + '  {' 
                  +       '"Core_Customer_Number__c":"' + ID_ACCOUNT1 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING1 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Total_Checksum__c":"8888","Test_Field__c":"Test Text","Save_without_Email__c":true,"Contacts":'
                  +       '[' 
                  +       '   {"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+4930127633","Salutation":"Mrs.","Save_without_Email__c":true},{"PersonID__c":"'+ ID_CONTACT2 + '","FirstName":"Bettina","LastName":"Test","Phone":"+4930127633","Salutation":"Mrs.","Save_without_Email__c":true}'
                  +       ']'
                  + '  }'
                  + ']';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;
        
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processAccountList(IDS_ACCOUNT);
                Test.stopTest();
        }

        assertAccountContactRelationsExist(IDS_ACCOUNT, IDS_CONTACT, 2);
    }

    @isTest
    public static void test_coreCommercialAdministratorLookup(){
        Profile prof = [SELECT Id FROM Profile WHERE Name LIKE '%Administrator%' LIMIT 1]; 
        User us = new User(AD_Login_Name__c = CORE_COMMERCIAL_ADMIN, Alias = 'ATU',Email = 'ApexTestUser@test.test',EmailEncodingKey = 'UTF-8',LastName = 'Apex Test User',LanguageLocaleKey = 'en_US',LocaleSidKey = 'de_DE_EURO',ProfileId = prof.Id,TimeZoneSidKey = 'Europe/Berlin',UserName = 'ApexTestUser@test.test');
        insert us;

        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1};
        IDS_CONTACT = new Set<String>{ID_CONTACT1,ID_CONTACT2};

        String response =
                  '['
                  + '  {' 
                  +       '"Core_Customer_Number__c":"' + ID_ACCOUNT1 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING1 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Total_Checksum__c":"8888","Save_without_Email__c":true,"Core_Commercial_Administrator__c":"AdminX","Contacts":'
                  +       '[' 
                  +       '   {"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+4930127633","Salutation":"Mrs.","Save_without_Email__c":true},{"PersonID__c":"'+ ID_CONTACT2 + '","FirstName":"Bettina","LastName":"Test","Phone":"+4930127633","Salutation":"Mrs.","Save_without_Email__c":true}'
                  +       ']'
                  + '  }'
                  + ']';

        
        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;
        
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processAccountList(IDS_ACCOUNT);
                Test.stopTest();
        }

        assertUserLookup(us.Id, ID_ACCOUNT1);
    }

    @isTest
    public static void test_invalidWZCode(){

        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1};
        IDS_CONTACT = new Set<String>{ID_CONTACT1,ID_CONTACT2};

        String response =
                  '['
                  + '  {' +
                  +       '"Core_Customer_Number__c":"' + ID_ACCOUNT1 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING1 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Total_Checksum__c":"8888","Core_WZ_Code_1__c":"12345","Save_without_Email__c":true,"Contacts":'
                  +       '[' +
                  +       '   {"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+4930127633","Salutation":"Mrs.","Save_without_Email__c":true},{"PersonID__c":"'+ ID_CONTACT2 + '","FirstName":"Bettina","LastName":"Test","Phone":"+4930127633","Salutation":"Mrs.","Save_without_Email__c":true}'
                  +       ']'
                  + '  }'
                  + ']';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;
        
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processAccountList(IDS_ACCOUNT);
                Test.stopTest();
        }

        assertAccountContactRelationsExist(IDS_ACCOUNT, IDS_CONTACT, 2);
        assertErrorLogsExist(1);
    }

    @isTest
    public static void test_duplicateContact(){

        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1,ID_ACCOUNT2,ID_ACCOUNT3};
        IDS_CONTACT = new Set<String>{ID_CONTACT1,ID_CONTACT2,ID_CONTACT3};

        String response =
                '['
                +    '{'
                +        '"Core_Customer_Number__c":"' + ID_ACCOUNT1 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING1 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Total_Checksum__c":"135","Save_without_Email__c":true,"Contacts":'
                +            '['
                +               '{"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+491234567","Salutation":"Mrs.","Save_without_Email__c":true},'
                +               '{"PersonID__c":"'+ ID_CONTACT2 + '","FirstName":"Duplicate","LastName":"Test","Phone":"+4930127633","Salutation":"Mrs.","Save_without_Email__c":true}'
                +            ']'
                +    '},'
                +    '{'
                +        '"Core_Customer_Number__c":"' + ID_ACCOUNT2 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING2 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Total_Checksum__c":"531","Save_without_Email__c":true,"Contacts":'
                +            '['
                +               '{"PersonID__c":"'+ ID_CONTACT3 + '","FirstName":"TestName","LastName":"TestLastName","Phone":"+4998765432","Salutation":"Mrs.","Save_without_Email__c":true},'
                +               '{"PersonID__c":"'+ ID_CONTACT2 + '","FirstName":"Duplicate","LastName":"Test","Phone":"+4930127633","Salutation":"Mrs.","Save_without_Email__c":true}'
                +            ']'
                +    '},'
                +    '{'
                +        '"Core_Customer_Number__c":"' + ID_ACCOUNT3 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING3 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Total_Checksum__c":"4435","Save_without_Email__c":true,"Contacts":'
                +            '['
                +               '{"PersonID__c":"'+ ID_CONTACT3 + '","FirstName":"TestName","LastName":"TestLastName","Phone":"+4998765432","Salutation":"Mrs.","Save_without_Email__c":true},'
                +               '{"PersonID__c":"'+ ID_CONTACT2 + '","FirstName":"Duplicate","LastName":"Test","Phone":"+4930127633","Salutation":"Mrs.","Save_without_Email__c":true}'
                +            ']'
                +    '}'
                + ']';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;
        
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processAccountList(IDS_ACCOUNT);
                Test.stopTest();
        }

        assertAccountContactRelationsExist(IDS_ACCOUNT, IDS_CONTACT, 6);
    }

    @isTest
    public static void test_newAssertionExistingAccount(){

        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1};
        IDS_CONTACT = new Set<String>{ID_CONTACT1};

        Account acc = new Account(Core_Customer_Number__c= ID_ACCOUNT1, Core_Accounting_Area_SAP__c = '0100', Core_Customer_Type__c = '7', Name =  NAME_TESTING1, BillingStreet = 'Plan Str 1', BillingCity = 'MUC', BillingPostalCode = '81241', BillingCountry = 'DE', Phone = '+4989746221', Save_without_Email__c = true,Total_Checksum__c='12345');
        insert acc;

        String response =
                '['
                +    '{'
                +        '"Core_Customer_Number__c":"' + ID_ACCOUNT1 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING1 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Total_Checksum__c":"77665","Save_without_Email__c":true,"Contacts":'
                +            '['
                +               '{"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+491234567","Salutation":"Mrs.","Save_without_Email__c":true}'
                +            ']'
                +    '}'
                + ']';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processAccountList(IDS_ACCOUNT);
                Test.stopTest();
        }

        assertAccountContactRelationsExist(IDS_ACCOUNT, IDS_CONTACT, 1);
    }

    @isTest
    public static void test_contactDeletionCode(){
        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1};
        IDS_CONTACT = new Set<String>{ID_CONTACT1};

        Account acc = new Account(Core_Customer_Number__c= ID_ACCOUNT1, Core_Accounting_Area_SAP__c = '0100', Core_Customer_Type__c = '7', Name =  NAME_TESTING1, BillingStreet = 'Plan Str 1', BillingCity = 'MUC', BillingPostalCode = '81241', BillingCountry = 'DE', Phone = '+4989746221', Save_without_Email__c = true,Total_Checksum__c='12345');
        insert acc;
        Contact con = new Contact(PersonID__c = ID_CONTACT1, FirstName = 'Bettina', LastName = 'Oster', AccountId = acc.Id, MobilePhone = '+491234567', Salutation = 'Mrs.', Save_without_Email__c = true);
        insert con;


        String response =
                '['
                +    '{'
                +        '"Core_Customer_Number__c":"' + ID_ACCOUNT1 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING1 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Total_Checksum__c":"77665","Save_without_Email__c":true,"Contacts":'
                +            '['
                +               '{"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+491234567","Salutation":"Mrs.","Save_without_Email__c":true, "Deletion_Code__c":true}'
                +            ']'
                +    '}'
                + ']';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(thisUser){
                //assigning a deletion code in this case requires the running user to bypass validation rules
                Profile prof = [SELECT Id FROM Profile WHERE Name LIKE '%Administrator%' LIMIT 1]; 
                User us = new User(AD_Login_Name__c = CORE_COMMERCIAL_ADMIN, Alias = 'ATU',Email = 'ApexTestUser@test.test',EmailEncodingKey = 'UTF-8',LastName = 'Apex Test User',LanguageLocaleKey = 'en_US',LocaleSidKey = 'de_DE_EURO',ProfileId = prof.Id,TimeZoneSidKey = 'Europe/Berlin',UserName = 'ApexTestUser@test.test');
                insert us;

                PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name LIKE '%Core_Bypass_Validation_Rules%' LIMIT 1];
                insert new PermissionSetAssignment(AssigneeId = us.id, PermissionSetId = ps.Id);

                System.runAs(us){
                        Test.startTest();
                                testService.processAccountList(IDS_ACCOUNT);
                        Test.stopTest();
                }
        }

        assertAccountContactRelationDeletion(IDS_ACCOUNT, IDS_CONTACT, 1);
        assertContactDeletion(IDS_CONTACT, 1);
    }

    @isTest
    public static void test_ACRNonDirectDeletionCode(){

        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1, ID_ACCOUNT2};
        IDS_CONTACT = new Set<String>{ID_CONTACT1};

        Account acc1 = new Account(Core_Customer_Number__c= ID_ACCOUNT1, Core_Accounting_Area_SAP__c = '0100', Core_Customer_Type__c = '7', Name =  NAME_TESTING1, BillingStreet = 'Plan Str 1', BillingCity = 'MUC', BillingPostalCode = '81241', BillingCountry = 'DE', Phone = '+4989746221', Save_without_Email__c = true,Total_Checksum__c='12345');
        insert acc1;
        Account acc2 = new Account(Core_Customer_Number__c= ID_ACCOUNT2, Core_Accounting_Area_SAP__c = '0100', Core_Customer_Type__c = '7', Name =  NAME_TESTING2, BillingStreet = 'Plan Str 2', BillingCity = 'MUC', BillingPostalCode = '99999', BillingCountry = 'DE', Phone = '+4967767862', Save_without_Email__c = true,Total_Checksum__c='12345');
        insert acc2;
        Contact con = new Contact(PersonID__c = ID_CONTACT1, FirstName = 'Bettina', LastName = 'Oster', AccountId = acc2.Id, MobilePhone = '+491234567', Salutation = 'Mrs.', Save_without_Email__c = true);
        insert con;
        AccountContactRelation accConRelation = new AccountContactRelation(AccountId = acc1.Id, ContactId = con.Id, Role__c = 'ARCH');
        insert accConRelation;

        assertDirectACR(ID_ACCOUNT2, ID_CONTACT1, 1);

        String response =
                '['
                +    '{'
                +        '"Core_Customer_Number__c":"' + ID_ACCOUNT1 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING1 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Total_Checksum__c":"77665","Save_without_Email__c":true,"Contacts":'
                +            '['
                +               '{"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+491234567","Salutation":"Mrs.","Save_without_Email__c":true, "Deletion_Code__c":true}'
                +            ']'
                +    '}'
                + ']';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processAccountList(IDS_ACCOUNT);
                Test.stopTest();
        }

        assertAccountContactRelationDeletion(IDS_ACCOUNT, IDS_CONTACT, 1);
        assertContactDeletion(IDS_CONTACT, 0);
        assertDirectACR(ID_ACCOUNT2, ID_CONTACT1, 1);
    }

    @isTest
    public static void test_ACRDirectDeletionCode(){

        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1, ID_ACCOUNT2};
        IDS_CONTACT = new Set<String>{ID_CONTACT1};

        Account acc1 = new Account(Core_Customer_Number__c= ID_ACCOUNT1, Core_Accounting_Area_SAP__c = '0100', Core_Customer_Type__c = '7', Name =  NAME_TESTING1, BillingStreet = 'Plan Str 1', BillingCity = 'MUC', BillingPostalCode = '81241', BillingCountry = 'DE', Phone = '+4989746221', Save_without_Email__c = true,Total_Checksum__c='12345');
        insert acc1;
        Account acc2 = new Account(Core_Customer_Number__c= ID_ACCOUNT2, Core_Accounting_Area_SAP__c = '0100', Core_Customer_Type__c = '7', Name =  NAME_TESTING2, BillingStreet = 'Plan Str 2', BillingCity = 'MUC', BillingPostalCode = '99999', BillingCountry = 'DE', Phone = '+4967767862', Save_without_Email__c = true,Total_Checksum__c='12345');
        insert acc2;
        Contact con = new Contact(PersonID__c = ID_CONTACT1, FirstName = 'Bettina', LastName = 'Oster', AccountId = acc1.Id, MobilePhone = '+491234567', Salutation = 'Mrs.', Save_without_Email__c = true);
        insert con;
        AccountContactRelation accConRelation = new AccountContactRelation(AccountId = acc2.Id, ContactId = con.Id, Role__c = 'ARCH');
        insert accConRelation;

        assertDirectACR(ID_ACCOUNT2, ID_CONTACT1, 0);

        String response =
                '['
                +    '{'
                +        '"Core_Customer_Number__c":"' + ID_ACCOUNT1 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING1 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Total_Checksum__c":"77665","Save_without_Email__c":true,"Contacts":'
                +            '['
                +               '{"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+491234567","Salutation":"Mrs.","Save_without_Email__c":true, "Deletion_Code__c":true}'
                +            ']'
                +    '}'
                + ']';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processAccountList(IDS_ACCOUNT);
                Test.stopTest();
        }

        assertAccountContactRelationDeletion(IDS_ACCOUNT, IDS_CONTACT, 1);
        assertContactDeletion(IDS_CONTACT, 0);
        assertDirectACR(ID_ACCOUNT2, ID_CONTACT1, 1);
    }

    @isTest
    public static void test_convertAccount(){

        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1};
        IDS_CONTACT = new Set<String>{ID_CONTACT1};

        Account acc = new Account(Core_Customer_Number__c= ID_ACCOUNT2, Core_Accounting_Area_SAP__c = '0100', Core_Customer_Type__c = '7', Name =  NAME_TESTING1, BillingStreet = 'Plan Str 1', BillingCity = 'MUC', BillingPostalCode = '81241', BillingCountry = 'DE', Phone = '+4989746221', Save_without_Email__c = true, Total_Checksum__c='3434');
        insert acc;

        String response =
                '['
                +    '{'
                +        '"Core_Customer_Number__c":"' + ID_ACCOUNT1 + '","Old_Customer_Number__c": "'+ ID_ACCOUNT2 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING1 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Total_Checksum__c":"9898","Save_without_Email__c":true,"Contacts":'
                +            '['
                +               '{"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+491234567","Salutation":"Mrs.","Save_without_Email__c":true}'
                +            ']'
                +    '}'
                + ']';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;
        
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processAccountList(IDS_ACCOUNT);
                Test.stopTest();
        }

        assertAccountContactRelationsExist(IDS_ACCOUNT, IDS_CONTACT, 1);
        assertAccountConversion(ID_ACCOUNT2, ID_ACCOUNT1);
    }

    @isTest
    public static void test_convertedAccountContactRelation(){

        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1};
        IDS_CONTACT = new Set<String>{ID_CONTACT1};

        Account acc = new Account(Core_Customer_Number__c= ID_ACCOUNT2, Core_Accounting_Area_SAP__c = '0100', Core_Customer_Type__c = '7', Name =  NAME_TESTING3, BillingStreet = 'Plan Str 1', BillingCity = 'MUC', BillingPostalCode = '81241', BillingCountry = 'DE', Phone = '+4989746221', Save_without_Email__c = true,Total_Checksum__c='12345');
        insert acc;
        Contact con = new Contact(PersonID__c = ID_CONTACT1, FirstName = 'Bettina', LastName = 'Oster', AccountId = acc.Id, MobilePhone = '+491234567', Salutation = 'Mrs.', Save_without_Email__c = true);
        insert con;

        String response =
                '['
                +    '{'
                +        '"Core_Customer_Number__c":"' + ID_ACCOUNT1 + '","Old_Customer_Number__c": "'+ ID_ACCOUNT2 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING1 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Total_Checksum__c":"876543","Save_without_Email__c":true,"Contacts":'
                +            '['
                +               '{"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+491234567","Salutation":"Mrs.","Save_without_Email__c":true}'
                +            ']'
                +    '}'
                + ']';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processAccountList(IDS_ACCOUNT);
                Test.stopTest();
        }

        assertAccountContactRelationsExist(IDS_ACCOUNT, IDS_CONTACT, 1);
        assertAccountConversion(ID_ACCOUNT2, ID_ACCOUNT1);
        assertAccountContactRelationConversion(IDS_ACCOUNT, IDS_CONTACT);
    }

    @isTest
    public static void test_upsertErrorLog(){

        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1};
        IDS_CONTACT = new Set<String>{ID_CONTACT1};

        String response =
                  '['
                  + '  {' +
                  +       '"Core_Customer_Type__c":"999","Core_Customer_Number__c":"' + ID_ACCOUNT1 + '","Core_Accounting_Area_SAP__c":"0100","Name":"'+ NAME_TESTING1 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"error","Total_Checksum__c":"6565","Save_without_Email__c":true,"Contacts":'
                  +       '[' +
                  +       '   {"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+4930127633","Salutation":"Mrs.","Save_without_Email__c":true},{"PersonID__c":"'+ ID_CONTACT2 + '","FirstName":"Bettina","LastName":"Test","Phone":"+4930127633","Salutation":"Mrs.","Save_without_Email__c":true}'
                  +       ']'
                  + '  }'
                  + ']';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processAccountList(IDS_ACCOUNT);
                Test.stopTest();
        }

        assertErrorLogsExist(1);

    }

    @isTest
    public static void test_updateErrorLog(){

        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1};
        IDS_CONTACT = new Set<String>{ID_CONTACT1};

        Account acc = new Account(Core_Customer_Number__c= ID_ACCOUNT2, Core_Accounting_Area_SAP__c = '0100', Core_Customer_Type__c = '7', Name =  NAME_TESTING2, BillingStreet = 'Plan Str 1', BillingCity = 'MUC', BillingPostalCode = '81241', BillingCountry = 'DE', Phone = '+4989746221', Save_without_Email__c = true, Total_Checksum__c='12345');
        insert acc;

        String response =
                '['
                +    '{'
                +        '"Core_Customer_Type__c":"999","Core_Customer_Number__c":"' + ID_ACCOUNT1 + '","Old_Customer_Number__c": "'+ ID_ACCOUNT2 + '","Core_Accounting_Area_SAP__c":"0100","Name":"'+ NAME_TESTING1 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"error","Total_Checksum__c":"1333","Save_without_Email__c":true,"Contacts":'
                +            '['
                +               '{"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+491234567","Salutation":"Mrs.","Save_without_Email__c":true}'
                +            ']'
                +    '}'
                + ']';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processAccountList(IDS_ACCOUNT);
                Test.stopTest();
        }

        assertErrorLogsExist(1);
    }


    @isTest
    public static void test_processCdcAccounts(){

        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1};
        IDS_CONTACT = new Set<String>{ID_CONTACT1,ID_CONTACT2};

        String response =
                  '['
                  + '  {' +
                  +       '"Core_Customer_Number__c":"' + ID_ACCOUNT1 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING1 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Total_Checksum__c":"123456", "Save_without_Email__c":true,"Contacts":'
                  +       '[' +
                  +       '   {"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+4930127633","Salutation":"Mrs.","Save_without_Email__c":true},{"PersonID__c":"'+ ID_CONTACT2 + '","FirstName":"Bettina","LastName":"Test","Phone":"+4930127633","Salutation":"Mrs.","Save_without_Email__c":true}'
                  +       ']'
                  + '  }'
                  + ']';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processCdcAccounts(1);
                Test.stopTest();
        }
        
        assertAccountContactRelationsExist(IDS_ACCOUNT, IDS_CONTACT, 2);
    }

    @isTest
    public static void test_unchangedContactJobTitle(){

        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT2};
        IDS_CONTACT = new Set<String>{ID_CONTACT1};

        Account acc = new Account(Core_Customer_Number__c= ID_ACCOUNT1, Core_Accounting_Area_SAP__c = '0100', Core_Customer_Type__c = '7', Name =  NAME_TESTING1, BillingStreet = 'Plan Str 1', BillingCity = 'MUC', BillingPostalCode = '81241', BillingCountry = 'DE', Phone = '+4989746221', Save_without_Email__c = true, Total_Checksum__c='12345');
        insert acc;
        Contact con = new Contact(PersonID__c = ID_CONTACT1, FirstName = 'Bettina', LastName = 'Oster', AccountId = acc.Id, MobilePhone = '+491234567', Salutation = 'Mrs.', Save_without_Email__c = true, Job_Title__c = 'BAUL');
        insert con;

        String response =
                '['
                +    '{'
                +        '"Core_Customer_Number__c":"' + ID_ACCOUNT2 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING2 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Total_Checksum__c":"88888","Phone":"+4989746221","Save_without_Email__c":true,"Contacts":'
                +            '['
                +               '{"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+491234567","Salutation":"Mrs.","Save_without_Email__c":true,"Job_Title__c":"BAUH"}'
                +            ']'
                +    '}'
                + ']';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processAccountList(IDS_ACCOUNT);
                Test.stopTest();
        }

        assertContactJobTitle(ID_CONTACT1, 'BAUL');
    }

    @isTest
    public static void test_unchangedContactJobTitleCheckSum(){

        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1};
        IDS_CONTACT = new Set<String>{ID_CONTACT1};

        Account acc = new Account(Core_Customer_Number__c= ID_ACCOUNT1, Core_Accounting_Area_SAP__c = '0100', Core_Customer_Type__c = '7', Name =  NAME_TESTING1, BillingStreet = 'Plan Str 1', BillingCity = 'MUC', BillingPostalCode = '81241', BillingCountry = 'DE', Phone = '+4989746221', Save_without_Email__c = true,Total_Checksum__c='12345');
        insert acc;
        Contact con = new Contact(PersonID__c = ID_CONTACT1, FirstName = 'Bettina', LastName = 'Oster', AccountId = acc.Id, MobilePhone = '+491234567', Salutation = 'Mrs.', Save_without_Email__c = true, Job_Title__c = 'BAUL');
        insert con;

        String response =
                  '['
                  + '  {' +
                  +       '"Core_Customer_Number__c":"' + ID_ACCOUNT1 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING1 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Total_Checksum__c":"12345","Save_without_Email__c":true,"Contacts":'
                  +       '[' +
                  +       '   {"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+491234567","Salutation":"Mrs.","Save_without_Email__c":true, "Job_Title__c":"BAUH"}'
                  +       ']'
                  + '  }'
                  + ']';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processAccountList(IDS_ACCOUNT);
                Test.stopTest();
        }

        assertContactJobTitle(ID_CONTACT1, 'BAUL');
    }

    @isTest
    public static void test_changedContactJobTitle(){

        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1};
        IDS_CONTACT = new Set<String>{ID_CONTACT1};

        Account acc = new Account(Core_Customer_Number__c= ID_ACCOUNT1, Core_Accounting_Area_SAP__c = '0100', Core_Customer_Type__c = '7', Name =  NAME_TESTING1, BillingStreet = 'Plan Str 1', BillingCity = 'MUC', BillingPostalCode = '81241', BillingCountry = 'DE', Phone = '+4989746221', Save_without_Email__c = true,Total_Checksum__c='12345');
        insert acc;
        Contact con = new Contact(PersonID__c = ID_CONTACT1, FirstName = 'Bettina', LastName = 'Oster', AccountId = acc.Id, MobilePhone = '+491234567', Salutation = 'Mrs.', Save_without_Email__c = true, Job_Title__c = 'BAUL');
        insert con;

        String response =
                  '['
                  + '  {' +
                  +       '"Core_Customer_Number__c":"' + ID_ACCOUNT1 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING1 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Total_Checksum__c":"77777","Save_without_Email__c":true,'
                  +     '"Territory":' 
                  +     '['
                  +             '{"zip": "03042","businessarea": 1,"salesunitid": "M011","salesunit": "Mietstation Cottbus","region": "0302","regionname": "07 Berlin/Brandenburg","businessareaname": "Maschinen- & Gerätevermietung"},'
                  +             '{"zip": "03042","businessarea": 2,"salesunitid": "M455","salesunit": "Kompetenz-Center Containervermietung Berlin-Hohenschönh.","region": "MIU8","regionname": "Produkt-/Sonderbereiche","businessareaname": "Raumsysteme"}'
                  +     '],'
                  +     '"Contacts":'
                  +       '[' +
                  +       '   {"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+491234567","Salutation":"Mrs.","Save_without_Email__c":true, "Job_Title__c":"BAUH"}'
                  +       ']'
                  + '  }'
                  + ']';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processAccountList(IDS_ACCOUNT);
                Test.stopTest();
        }

        assertContactJobTitle(ID_CONTACT1, 'BAUH');
    }

    @isTest
    public static void test_newRelationExistingContact(){
        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1,ID_ACCOUNT2};
        IDS_CONTACT = new Set<String>{ID_CONTACT1,ID_CONTACT2};

        Account acc = new Account(Core_Customer_Number__c = ID_ACCOUNT1,Core_Accounting_Area_SAP__c = '0100',Core_Customer_Type__c = '7',Name = NAME_TESTING1,BillingStreet = 'Leopoldstraße 29',BillingCity ='München',BillingPostalCode ='80802',BillingCountry = 'DE',Phone = '+49 30123456',Core_Email__c ='ritter@kokonuss.com', Total_Checksum__c='12345');
        insert acc;
        Contact con = new Contact(PersonID__c = ID_CONTACT1, FirstName = 'Test Cont Exist 1', LastName = 'Exist 1', AccountId = acc.Id, Phone = '+49 123456799',Salutation ='Mr.',Job_Title__c= 'ARCH',Save_without_Email__c = true,Deletion_Code__c = false);
        insert con;

        Account acc2 = new Account(Core_Customer_Number__c = ID_ACCOUNT2,Core_Accounting_Area_SAP__c = '0100',Core_Customer_Type__c = '7',Name = NAME_TESTING2,BillingStreet = 'Hanauer Straße 1',BillingCity ='München',BillingPostalCode ='80992',BillingCountry = 'DE',Phone = '+49 123456789',Core_Email__c ='bond@sieben.com', Total_Checksum__c='98765');
        insert acc2;
        Contact con2 = new Contact(PersonID__c = ID_CONTACT2, FirstName = 'Blau', LastName = 'Grün', AccountId = acc2.Id, Phone = '+49 98765431',Salutation ='Mrs.',Job_Title__c= 'ARCH',Save_without_Email__c = true,Deletion_Code__c = false);
        insert con2;

        String response =
                '['
                + '{'
                +   '"Core_Customer_Number__c": "'+ ID_ACCOUNT1 +'","Core_Accounting_Area_SAP__c": "0100","Core_Customer_Type__c": "7","Name": "'+ NAME_TESTING1 +'","BillingStreet": "Leopoldstraße 29","BillingCity": "München","BillingPostalCode": "80802","BillingCountry": "DE","Phone": "+49 30123456","Core_Email__c": "ritter@kokonuss.com","Total_Checksum__c":"999","Save_without_Email__c": false,'
                +       '"Contacts":'
                +       '['
                +            '{"PersonID__c": "'+ ID_CONTACT1 +'","FirstName": "Ritter","LastName": "Kokosnuss","Phone": "+49 123456799","Salutation": "Mr.","Job_Title__c": "ARCH","Save_without_Email__c": true}'
                +       ']'
                + '},'
                + '{'
                +  '"Core_Customer_Number__c": "'+ ID_ACCOUNT2 +'","Core_Accounting_Area_SAP__c": "0100","Core_Customer_Type__c": "7","Name": "'+ NAME_TESTING2 +'","BillingStreet": "Hanauer Straße 1","BillingCity": "München","BillingPostalCode": "80992","BillingCountry": "DE","Phone": "+49 123456789","Core_Email__c": "bond@sieben.com","Total_Checksum__c":"959","Save_without_Email__c": false,'
                +    '"Contacts": ['
                +          '{"PersonID__c": "'+ ID_CONTACT1 +'","FirstName": "Test Cont Exist 1" ,"LastName": "Exist 1","Phone": "+49 98765431","Salutation": "Mr.","Job_Title__c": "DL","Save_without_Email__c": true}'
                +    ']'
                +'}]';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );

        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processAccountList(IDS_ACCOUNT);
                Test.stopTest();
        }

        assertAccountContactRelationsExist(IDS_ACCOUNT, IDS_CONTACT, 3);
    }

    @isTest
    public static void test_sourceSystem(){

        Account acc2 = new Account(Core_Customer_Number__c = ID_ACCOUNT2,Core_Accounting_Area_SAP__c = '0100',Core_Customer_Type__c = '7',Name = NAME_TESTING2,BillingStreet = 'Hanauer Straße 1',BillingCity ='München',BillingPostalCode ='80992',BillingCountry = 'DE',Phone = '+49 123456789',Core_Email__c ='bond@sieben.com', Core_Source_System__c = 'Salesforce', Total_Checksum__c='98765');
        insert acc2;
        Contact con2 = new Contact(PersonID__c = ID_CONTACT2, FirstName = 'Blau', LastName = 'Grün', AccountId = acc2.Id, Phone = '+49 98765431',Salutation ='Mrs.',Job_Title__c= 'ARCH',Save_without_Email__c = true,Core_Source_System__c = 'Salesforce',Deletion_Code__c = false);
        insert con2;

        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1,ID_ACCOUNT2};

        String response =
                '['
                +    '{'
                +        '"Core_Customer_Number__c":"' + ID_ACCOUNT1 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING1 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Save_without_Email__c":true,"Contacts":'
                +            '['
                +               '{"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+491234567","Salutation":"Mrs.","Save_without_Email__c":true}'
                +            ']'
                +    '},'
                +    '{'
                +        '"Core_Customer_Number__c":"' + ID_ACCOUNT2 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING2 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Save_without_Email__c":true,"Contacts":'
                +            '['
                +               '{"PersonID__c":"'+ ID_CONTACT2 + '","FirstName":"Contact","LastName":"Test","Phone":"+4930127633","Salutation":"Mrs.","Save_without_Email__c":true}'
                +            ']'
                +    '}'
                + ']';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processAccountList(IDS_ACCOUNT);
                Test.stopTest();
        }

        assertSourceSystemAccount(ID_ACCOUNT1, 'Grace');
        assertSourceSystemAccount(ID_ACCOUNT2, 'Salesforce');
        assertSourceSystemContact(ID_CONTACT1, 'Grace');
        assertSourceSystemContact(ID_CONTACT2, 'Salesforce');

    }

    @isTest
    public static void test_newTerritoriesExistingAccount(){
        Territory2 terr = [SELECT Id, Name, Core_External_ID__c FROM Territory2 WHERE Core_External_ID__c = : TTRAccountHandlerTest.SALESUNIT_ID_TESTING1 LIMIT 1];

        IDS_ACCOUNT = new Set<String>{ID_ACCOUNT1};
        Account acc = new Account(Core_Customer_Number__c= ID_ACCOUNT1, Core_Accounting_Area_SAP__c = '0100', Core_Customer_Type__c = '7', Name =  NAME_TESTING1, BillingStreet = 'Plan Str 1', BillingCity = 'MUC', BillingPostalCode = '81241', BillingCountry = 'DE', Phone = '+4989746221', Save_without_Email__c = true,Total_Checksum__c='12345');
        insert acc;

        ObjectTerritory2Association objectTerritory2Association = new ObjectTerritory2Association();
        objectTerritory2Association.Territory2Id = terr.Id;
        objectTerritory2Association.ObjectId = acc.Id;
        objectTerritory2Association.AssociationCause = 'Territory2Manual';
        insert objectTerritory2Association;

        String response =
                '['
                +    '{'
                +        '"Core_Customer_Number__c":"' + ID_ACCOUNT1 + '","Core_Accounting_Area_SAP__c":"0100","Core_Customer_Type__c":"7","Name":"'+ NAME_TESTING1 + '","BillingStreet":"Plan Str 1","BillingCity":"MUC","BillingPostalCode":"81241","BillingCountry":"DE","Phone":"+4989746221","Total_Checksum__c":"77665","Save_without_Email__c":true,'
                +     '"Territory":' 
                +     '['
                +             '{"zip": "03042","businessarea": 2,"salesunitid": "' + TTRAccountHandlerTest.SALESUNIT_ID_TESTING2 + '","salesunit": "Kompetenz-Center Containervermietung Berlin-Hohenschönh.","region": "MIU8","regionname": "Produkt-/Sonderbereiche","businessareaname": "Raumsysteme"}'
                +     '],'
                +       '"Contacts":'
                +            '['
                +               '{"PersonID__c":"'+ ID_CONTACT1 + '","FirstName":"Bettina","LastName":"Oster","Phone":"+491234567","Salutation":"Mrs.","Save_without_Email__c":true}'
                +            ']'
                +    '}'
                + ']';

        Test.setMock(
                HttpCalloutMock.class,
                UTLMockHttpResponse.builder()
                        .statusCode(200)
                        .body(response).next()

        );
        GRSYAccService testService = new GRSYAccService();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
                Test.startTest();
                        testService.processAccountList(IDS_ACCOUNT);
                Test.stopTest();
        }

        assertObjectTerritory2Association(IDS_ACCOUNT,TTRAccountHandlerTest.SALESUNIT_ID_TESTING2,1);
        assertObjectTerritory2Association(IDS_ACCOUNT,TTRAccountHandlerTest.SALESUNIT_ID_TESTING1,0);
    }

    /**
     * Assert Accounts, Contacts and their AccountContactRelation were successfully created
     *
     * @param accountIds Set of input Accounts
     * @param contactIds Set of input Contacts with AccountContactRelations to input Accounts
     * @param count expected number of AccountContactRelations
     */
    private static void assertAccountContactRelationsExist(Set<String> accountIds, Set<String> contactIds, Integer count) {

        List<AccountContactRelation> accountContactRelation = [
                SELECT Id, Account.Core_Customer_Number__c, Contact.PersonID__c, Contact.FirstName, External_ID__c
                FROM AccountContactRelation
                WHERE Account.Core_Customer_Number__c IN :accountIds AND Contact.PersonID__c IN :contactIds
        ];

        List<Account> accountList =[
            SELECT Id, Name, Core_Customer_Number__c
            FROM Account
            WHERE Core_Customer_Number__c IN :accountIds];

        List<Contact> contactList = [
            SELECT Id, Firstname, Lastname, PersonID__c
            FROM Contact
            WHERE PersonID__c IN :contactIds];

        System.assertEquals(count,accountContactRelation.size());
        System.assertEquals(accountIds.size(),accountList.size());
        System.assertEquals(contactIds.size(),contactList.size());
    }

    /**
     * Assert AccountContactRelation were successfully marked with Deletion Code
     *
     * @param accountIds Set of input Accounts
     * @param contactIds Set of input Contacts with AccountContactRelations to input Accounts
     * @param count expected number of deleted AccountContactRelations
     */
    private static void assertAccountContactRelationDeletion(Set<String> accountIds, Set<String> contactIds, Integer count) {

        List<AccountContactRelation> accountContactRelation = [
                SELECT Id, Account.Core_Customer_Number__c, Contact.PersonID__c, Contact.FirstName, External_ID__c
                FROM AccountContactRelation
                WHERE Account.Core_Customer_Number__c IN :accountIds AND Contact.PersonID__c IN :contactIds AND Deletion_Code__c = true
        ];

        System.assertEquals(count,accountContactRelation.size());
    }

    /**
     * Assert AccountContactRelation were successfully marked as direct
     *
     * @param accountId Account Id of direct ACR
     * @param contactId Contact Id of direct ACR
     * @param count expected number of direct AccountContactRelations
     */
    private static void assertDirectACR(String accountId, String contactId, Integer count) {

        List<AccountContactRelation> accountContactRelation = [
                SELECT Id, Account.Core_Customer_Number__c, Contact.PersonID__c, Contact.FirstName, External_ID__c
                FROM AccountContactRelation
                WHERE Account.Core_Customer_Number__c  = : accountId AND Contact.PersonID__c = : contactId AND IsDirect = true 
        ];

        System.assertEquals(count,accountContactRelation.size());
    }

    /**
     * Assert Contacts where successfully marked with Deletion Code
     *
     * @param contactIds Set of input Contacts 
     * @param count expected number of deleted Contacts
     */
    private static void assertContactDeletion(Set<String> contactIds, Integer count) {

        List<Contact> contactList = [
            SELECT Id, Firstname, Lastname, PersonID__c
            FROM Contact
            WHERE PersonID__c IN :contactIds AND Deletion_Code__c = true];

        System.assertEquals(count,contactList.size());
    }


    /**
     * Assert Account Core_Customer_Number__c was successfully converted and Old_Customer_Number__c successfully filled
     *
     * @param oldId old Core_Customer_Number__c which should no longer exist
     * @param newId new  Core_Customer_Number__c which should exist with oldId as Old_Customer_Number__c
     */
    private static void assertAccountConversion(String oldId, String newId) {

        List<Account> oldAccount = [
                SELECT Id, Core_Customer_Number__c
                FROM Account
                WHERE Core_Customer_Number__c =: oldId
        ];

        List<Account> newAccount = [
                SELECT Id, Core_Customer_Number__c,Old_Customer_Number__c
                FROM Account
                WHERE Core_Customer_Number__c =: newId AND Old_Customer_Number__c=: oldId
        ];

        System.assertEquals(0,oldAccount.size());
        System.assertEquals(1,newAccount.size());
    }

    /**
     * Assert user lookup Core_Commercial_Administrator__c on account was correctly filled
     *
     * @param userID id of the user that the lookup should refer to 
     * @param accID Core_Customer_Number__c of account in mock response
     */
    private static void assertUserLookup(String userID, String accID) {

        List<Account> accountList = [
                SELECT Id, Core_Customer_Number__c,Core_Commercial_Administrator__c
                FROM Account
                WHERE Core_Customer_Number__c =: accID 
        ];

        System.assertEquals(userID,accountList[0].Core_Commercial_Administrator__c);
    }

    /**
     * Assert an error log record was created for the class GRSYCAccService
     *
     * @param count number of errorLogs that should exist
     */
    private static void assertErrorLogsExist(Integer count) {
        List<Core_Error_Log__c> errorLogList = [
                SELECT Id,Core_Apex_Class__c
                FROM Core_Error_Log__c
                WHERE Core_Apex_Class__c =: 'GRSYAccService'
        ];

        System.assertEquals(count, errorLogList.size());
    }

     /**
     * Assert sourceSystem set on account
     *
     * @param sourceSystem expected source system
     * @param accountId Id from Account to check source system
     */
    private static void assertSourceSystemAccount(String accountId, String sourceSystem){
        List<Account> accountList =[
                SELECT Id, Name, Core_Customer_Number__c, Core_Source_System__c
                FROM Account
                WHERE Core_Customer_Number__c =: accountId];

         System.assertEquals(sourceSystem, accountList[0].Core_Source_System__c);
    }

    /**
     * Assert sourceSystem set on contact 
     *
     * @param sourceSystem sourceSystem from Grace response
     * @param accountId Id from Contact to check source system
     */
    private static void assertSourceSystemContact(String contactId, String sourceSystem){

        List<Contact> contactList =[
                SELECT Id, Name, PersonID__c, Core_Source_System__c
                FROM Contact
                WHERE PersonID__c =: contactId];

         System.assertEquals(sourceSystem, contactList[0].Core_Source_System__c);
    }


    /**
     * Assert AccountContactRelation was successfully converted by asserting that its External_ID__c matches the Core_Customer_Number__c
     * of the converted Account and the PersonID__c of the Contact
     *
     * @param accountIds Set of converted Accounts
     * @param contactIds Set of Contacts with AccountContactRelations to converted Accounts
     */
    private static void assertAccountContactRelationConversion(Set<String> accountIds, Set<String> contactIds) {

        String externalID = '';

        List<AccountContactRelation> accountContactRelation = [
                SELECT Id, Account.Core_Customer_Number__c, Contact.PersonID__c, Contact.FirstName, External_ID__c
                FROM AccountContactRelation
                WHERE Account.Core_Customer_Number__c IN :accountIds AND Contact.PersonID__c IN :contactIds
        ];

        List<Account> accountList =[
                SELECT Id, Name, Core_Customer_Number__c
                FROM Account
                WHERE Core_Customer_Number__c IN :accountIds];

        List<Contact> contactList = [
                SELECT Id, Firstname, Lastname, PersonID__c
                FROM Contact
                WHERE PersonID__c IN :contactIds];

        if(accountList != null && contactList != null){
                externalID = accountList[0].Core_Customer_Number__c + '_' + contactList[0].PersonID__c;
        }

        System.assertEquals(externalID, accountContactRelation[0].External_ID__c);

    }

    /**
     * Assert Job_Title__c on contact equals expected value
     *
     * @param conID PersonID of contact to check
     * @param jobTitle jobTitle from Grace response
     */
    private static void assertContactJobTitle(String conID, String jobTitle) {

        List<Contact> conList = [
                SELECT Id, Firstname, Lastname, PersonID__c, AccountId, Job_Title__c
                FROM Contact
                WHERE PersonID__c = : conID];

        System.assertEquals(jobTitle, conList[0].Job_Title__c);

    }

    /**
     * Assert Title__c on contact equals expected value
     *
     * @param conID PersonID of contact to check
     * @param title title from Grace response
     */
    private static void assertContactTitle(String conID, String title) {

        List<Contact> conList = [
                SELECT Id, Firstname, Lastname, PersonID__c, AccountId, Title__c
                FROM Contact
                WHERE PersonID__c = : conID];

        System.assertEquals(title, conList[0].Title__c);

    }

    /**
     * Assert Company_Group__c record was created
     *
     * @param compID ID of company group to check for
     * @param size amount of records that should be created
     */
    private static void assertCompanyGroup(String compID, Integer size) {

        List<Company_Group__c> compList = [
                SELECT Id
                FROM Company_Group__c
                WHERE Company_Group_ID__c = : compID];

        System.assertEquals(size, compList.size());

    }

    /**
     * Assert Company_Key__c record was created and assigned to the right Company Group
     *
     * @param compKeyID ID of company key to check for
     * @param compGroupID ID of company group that should be assigned
     * @param size amount of records that should be created
     */
    private static void assertCompanyKey(String compKeyID, String compGroupID, Integer size) {

        List<Company_Key__c> compKeyList = [
                SELECT Id, Company_Group__c
                FROM Company_Key__c
                WHERE Company_Key_ID__c = : compKeyID
                AND Company_Group__r.Company_Group_ID__c = : compGroupID];

        System.assertEquals(size, compKeyList.size());

    }

    /** 
     * Assert ObjectTerritory2Associations were successfully created
     *
     * @param accountIds Set of input Accounts
     * @param count expected number of ObjectTerritory2Associations
     */
    private static void assertObjectTerritory2Association(Set<String> accountIds, String territoryID, Integer count) {

        Map<Id,Account> accountMap = new Map<Id,Account>([
                SELECT Id, Name, Core_Customer_Number__c
                FROM Account
                WHERE Core_Customer_Number__c IN :accountIds]);

        List<ObjectTerritory2Association> territory2Associations = new List<ObjectTerritory2Association>(
            [
                SELECT Id, Territory2Id, ObjectId, Territory2.Core_External_ID__c
                FROM ObjectTerritory2Association
                WHERE ObjectId IN :accountMap.keySet() 
                AND Territory2.Core_External_ID__c = : territoryID
            ]
        );

        System.assertEquals(count,territory2Associations.size());
        
    }


}