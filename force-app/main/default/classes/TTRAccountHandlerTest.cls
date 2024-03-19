/**
 * AccountTriggerHandlerTest
 *
 * @author  daniel.gette@zeppelin.com
 *
 * @version 03.01.22 daniel.gette@zeppelin.com creation
 * @version 04.08.22 miriam.ida.tyroller@accenture.com
 */
@IsTest
public class TTRAccountHandlerTest {
    private static final String MOCK_API_KEY = '123456789';

    public final static String SALESUNIT_ID_TESTING1 = 'M123';
    public final static String SALESUNIT_ID_TESTING2 = 'M345';
    public final static String SALESUNIT_ID_MXXX = 'MXXX';

    private final static List<String> SALESUNIT_IDS_TESTING1 = new List<String>{ SALESUNIT_ID_TESTING1 };

    private static final String ZIP_TESTING1_MT = '87654';
    private static final String ZIP_TESTING2_MT = '43210';
    private static final String ZIP_CORRUPT_MT = '12345';

    /**
     * Create Account with min. required Fields
     * @return Account
     */
    private static Account createAccount() {
        Account account = new Account(Name = 'Test Acc');
        account.Save_without_Email__c = true;
        account.BillingCity = 'Test City';
        account.BillingPostalCode = '12345';
        account.BillingStreet = 'Test Street 1';
        return account;
    }

    /**
     * Create testData territoryList and based on that responsesByPlz
     * @return Map<String,String>
     */
    private static Map<String, String> createTestData() {
        List<Territory2> territoryList = [
            SELECT Id, Name, Core_External_ID__c
            FROM Territory2
            WHERE Name LIKE 'ApexTestTerritory%'
        ];

        Map<String, String> responsesByPlz = createMockResponseByPlz(territoryList);
        return responsesByPlz;
    }

    /**
     * Create test territories with min. required Fields, the creation needs to be placed in an TestSetup method to
     * avoid mixed dml operations
     */
    @TestSetup
    public static void createTerritories() {
        // Query one existing Territory to reuse the needed attributes
        List<Territory2> randomExistingTTrs = [SELECT Id, Territory2TypeId, Territory2ModelId FROM Territory2 LIMIT 3];
        Id ttrTypeId = randomExistingTTrs[1].Territory2TypeId;
        Id ttrModelId = randomExistingTTrs[1].Territory2ModelId;
        Id ttrParentId = randomExistingTTrs[1].Id;

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

    /**
     * Create MockResponse to assign test PLZs with created territories
     * @return Map<String,String>
     */
    public static Map<String, String> createMockResponseByPlz(List<Territory2> territoryList) {
        String responseString = '"zip":"{0}","salesunitid":"{1}","salesunit":"{2}"';
        String response1 = String.format(
            responseString,
            new List<String>{ ZIP_TESTING1_MT, territoryList[0].Core_External_ID__c, territoryList[0].Name }
        );
        String response2 = String.format(
            responseString,
            new List<String>{ ZIP_TESTING2_MT, territoryList[1].Core_External_ID__c, territoryList[1].Name }
        );
        String response3 = String.format(
            responseString,
            new List<String>{ ZIP_CORRUPT_MT, SALESUNIT_ID_MXXX, territoryList[1].Name, 'Mietstation Not Present' }
        );

        Map<String, String> responsesByPlz = new Map<String, String>{
            ZIP_TESTING1_MT => '[{' +
            response1 +
            '}]',
            ZIP_TESTING2_MT => '[{' +
            response2 +
            '}]',
            ZIP_CORRUPT_MT => '[{' +
            response3 +
            '}]'
        };
        return responsesByPlz;
    }

    @IsTest
    static void test_insertCreateTTRs() {
        Test.setMock(HttpCalloutMock.class, UTLMockHttpResponse.builder().statusCode(200));
        Map<String, String> responsesByPlz = createTestData();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;
        SHRGraceAPI.mockedSalesUnitsByPostalCodes = new Map<String, List<SHRGraceAPI.SalesUnit>>{
            ZIP_TESTING1_MT => (List<SHRGraceAPI.SalesUnit>) JSON.deserialize(
                responsesByPlz.get(ZIP_TESTING1_MT),
                List<SHRGraceAPI.SalesUnit>.class
            )
        };

        Test.startTest();
        Account acc = createAccount();
        acc.BillingPostalCode = ZIP_TESTING1_MT;
        insert acc;
        
        Test.stopTest();

       assertTerritoriesExists(acc.Id, SALESUNIT_IDS_TESTING1);
    }

    @IsTest
    static void test_insertEmptyResponse() {
        Test.setMock(
            HttpCalloutMock.class,
            UTLMockHttpResponse.builder()
                .statusCode(200) // first Call on Insert
                .next()
                .statusCode(200) // second Call on Update for old Account
        );

        Test.startTest();
        Account acc = createAccount();
        insert acc;
        Test.stopTest();

        assertTerritoriesExists(acc.Id, new List<String>{});
    }

    @IsTest
    static void test_insertTerritoryIdIsCorrupt() {
        Test.setMock(HttpCalloutMock.class, UTLMockHttpResponse.builder().statusCode(200));
        Map<String, String> responsesByPlz = createTestData();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;

        SHRGraceAPI.mockedSalesUnitsByPostalCodes = new Map<String, List<SHRGraceAPI.SalesUnit>>{
            ZIP_CORRUPT_MT => (List<SHRGraceAPI.SalesUnit>) JSON.deserialize(
                responsesByPlz.get(ZIP_CORRUPT_MT),
                List<SHRGraceAPI.SalesUnit>.class
            )
        };

        Test.startTest();
        Account acc = createAccount();
        acc.BillingPostalCode = ZIP_CORRUPT_MT;
        insert acc;
        Test.stopTest();

        System.assert((![SELECT Id FROM Core_Error_Log__c].isEmpty()));
    }

    @IsTest
    static void test_updateTerritoryGetsDeleted() {
        Test.setMock(
            HttpCalloutMock.class,
            UTLMockHttpResponse.builder()
                .statusCode(200) // first Call on Insert
                .next()
                .statusCode(200) // second Call on Update for old Account
                .next()
                .statusCode(200) // third Call on Update for new Account
        );
        Map<String, String> responsesByPlz = createTestData();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;

        SHRGraceAPI.mockedSalesUnitsByPostalCodes = new Map<String, List<SHRGraceAPI.SalesUnit>>{
            ZIP_TESTING2_MT => (List<SHRGraceAPI.SalesUnit>) JSON.deserialize(
                responsesByPlz.get(ZIP_TESTING2_MT),
                List<SHRGraceAPI.SalesUnit>.class
            )
        };

        Account account = createAccount();
        Test.startTest();
        account.BillingPostalCode = ZIP_TESTING2_MT;
        insert account;

        account.BillingPostalCode = ZIP_TESTING1_MT; // gets empty response
        update account;
        Test.stopTest();

        assertTerritoriesNotExists(account.Id, SALESUNIT_IDS_TESTING1);
    }

    @IsTest
    static void test_updateTerritoryIDsChanged() {
        Test.setMock(
            HttpCalloutMock.class,
            UTLMockHttpResponse.builder()
                .statusCode(200) // first Call on Insert
                .next()
                .statusCode(200) // second Call on Update for old Account
                .next()
                .statusCode(200) // third Call on Update for new Account
        );
        Map<String, String> responsesByPlz = createTestData();

        SHRGraceAPI.API_KEY = MOCK_API_KEY;
        SHRGraceAPI.mockedSalesUnitsByPostalCodes = new Map<String, List<SHRGraceAPI.SalesUnit>>{
            ZIP_TESTING2_MT => (List<SHRGraceAPI.SalesUnit>) JSON.deserialize(
                responsesByPlz.get(ZIP_TESTING2_MT),
                List<SHRGraceAPI.SalesUnit>.class
            ),
            ZIP_TESTING1_MT => (List<SHRGraceAPI.SalesUnit>) JSON.deserialize(
                responsesByPlz.get(ZIP_TESTING1_MT),
                List<SHRGraceAPI.SalesUnit>.class
            )
        };

        Account account = createAccount();
        Test.startTest();
        account.BillingPostalCode = ZIP_TESTING2_MT;
        insert account;

        account.BillingPostalCode = ZIP_TESTING1_MT;
        update account;
        Test.stopTest();

        // Assert
        assertTerritoriesNotExists(account.Id, new List<String>{ SALESUNIT_ID_TESTING2 });
        assertTerritoriesExists(account.Id, SALESUNIT_IDS_TESTING1);
    }

    @IsTest
    static void test_graceApiException() {
        Test.setMock(HttpCalloutMock.class, UTLMockHttpResponse.builder().statusCode(500));
        SHRGraceAPI.API_KEY = MOCK_API_KEY;

        Test.startTest();
        Account acc = createAccount();
        insert acc;
        Test.stopTest();

        Core_Error_Log__c coreErrorLog = [
            SELECT Id, Core_Error_Message__c, Core_Technical_Error_Message__c
            FROM Core_Error_Log__c
        ];
        System.assert(coreErrorLog.Core_Technical_Error_Message__c.contains('Grace-Api'));
        System.assert(coreErrorLog.Core_Technical_Error_Message__c.contains('error-code: 500'));
    }

    @IsTest
    static void test_calloutException() {
        Test.setMock(HttpCalloutMock.class, UTLMockHttpResponse.emptyBuilder().mockCalloutException('Read time out'));
        SHRGraceAPI.API_KEY = MOCK_API_KEY;

        Test.startTest();
        Account acc = createAccount();
        insert acc;
        Test.stopTest();

        Core_Error_Log__c coreErrorLog = [
            SELECT Id, Core_Error_Message__c, Core_Technical_Error_Message__c
            FROM Core_Error_Log__c
        ];
        System.assert(coreErrorLog.Core_Technical_Error_Message__c.contains('Read time out'));
    }

    /**
     * Query ObjectTerritory2Association and Assert by matching amount
     *
     * @param accountId Account  to filter by
     * @param territoryExternalIds List of Sales unit Id's aka External TerritoryId's
     */
    private static void assertTerritoriesExists(Id accountId, List<String> territoryExternalIds) {
        List<ObjectTerritory2Association> objectTerritory2Association = [
            SELECT Id, Territory2.Core_External_ID__c, ObjectId
            FROM ObjectTerritory2Association
            WHERE ObjectId = :accountId AND Territory2.Core_External_ID__c IN :territoryExternalIds
        ];
        System.assertEquals(
            territoryExternalIds.size(),
            objectTerritory2Association.size(),
            'Territories should be created'
        );
    }

    /**
     *
     * Query ObjectTerritory2Association and assume not to get an empty result set
     *
     * @param accountId Account filter By
     * @param territoryExternalIds List of Sales unit Id's aka External TerritoryId's
     */
    private static void assertTerritoriesNotExists(Id accountId, List<String> territoryExternalIds) {
        List<ObjectTerritory2Association> objectTerritory2Association = [
            SELECT Id, Territory2.Core_External_ID__c, ObjectId
            FROM ObjectTerritory2Association
            WHERE ObjectId = :accountId AND Territory2.Core_External_ID__c IN :territoryExternalIds
        ];
        System.assertEquals(0, objectTerritory2Association.size(), 'Territories shouldn\'t be present');
    }
}