/**
 * SF-848 Account-Vertriebsgebiete zuweisen
 * SF-911 Account-Sync mittels Grace-Aufruf
 *
 * Client consumes Grace API.
 *
 * @group SHR - Shared Functionality
 * @date 16.02.2022
 * @author  daniel.gette@zeppelin.com
 * 
 * @version 12.01.2023 miriam.ida.tyroller@accenture.com
 */
public with sharing class SHRGraceAPI {

    private static final String GRACE_CREDENTIAL = 'callout:GRACE_NP_PASS_BasicAuth';
    private static final String TERRITORY_V1_PATH = '/salesforce/territory/v1';
    private static final String CONTACT_V1_PATH = '/salesforce/contact/v1';
    private static final String ACCOUNT_V1_PATH = '/salesforce/account/v1';
    private static final String ACCOUNT_V1_LIST_PATH = '/salesforce/account/v3/list';
    private static final String CDC_ACCOUNT_V1_PATH = '/salesforce/cdc/v1/account';
    private static final String CDC_ACCOUNT_IDs_V1_PATH = '/salesforce/cdc/v1/accountids';

    private static String API_KEY_HEADER = 'apikey';
    @TestVisible
    private static String API_KEY = GRACE_API_Config__c.getOrgDefaults().Api_Key__c;

    /**
     * Finds  Salesunits by given postcodelist
     *
     * @param postalCodesByAccountIds postalCodes mapped with AccountIds
     * @param businessArea
     *
     * @return SalesUnits mapped by given postcodes
     */
    public static Map<String, List<SalesUnit>> getSalesUnitsByPostalCodeList(List<String> postalCodes) {
        // map request to list of PostCodeRequest
        PostCodeWrapperRequest postCodeListAreaRequest = mapPostCodeRequest(postalCodes);
        HttpResponse httpResponse = new UTLHttpRequestBuilder()
            .post(GRACE_CREDENTIAL + TERRITORY_V1_PATH + '/byzip/bulk')
            .setHeader(API_KEY_HEADER, API_KEY)
            .json(postCodeListAreaRequest)
            .setTimeout(80000)
            .send();

        if (httpResponse.getStatusCode() != 200)
            throw createGraceApiExeption(httpResponse);

     
        if (Test.isRunningTest()) {
          return mockSalesUnitsByPostalCodes(postalCodes);
        }
        
        return deserializeSalesUnitsByPostCodes(httpResponse.getBody());
    }

    /**
     * Finds all Salesunits by given postcode.
     *
     * @param postalCode
     *
     * @return list of Salesunits
     */
    public static List<SalesUnit> getSalesUnitsByPostalCodeV1(String postalCode) {
        HttpResponse httpResponse = new UTLHttpRequestBuilder()
            .get(GRACE_CREDENTIAL + TERRITORY_V1_PATH + '/byzip/' + postalCode)
            .setHeader(API_KEY_HEADER, API_KEY)
            .send();
        if (httpResponse.getStatusCode() != 200)
            throw createGraceApiExeption(httpResponse);
        return (List<SalesUnit>) JSON.deserialize(httpResponse.getBody(), List<SalesUnit>.class);
    }

    /**
     * Get Contact by personId.
     *
     * @param personId
     *
     * @return Contact mapped with PersonID
     */
    public static Map<String, Object> getContactByPersonId(String personId) {
        HttpResponse httpResponse = new UTLHttpRequestBuilder()
            .get(GRACE_CREDENTIAL + CONTACT_V1_PATH + '/bypersonid/' + personId)
            .setHeader(API_KEY_HEADER, API_KEY)
            .send();
        if (httpResponse.getStatusCode() != 200)
            throw createGraceApiExeption(httpResponse);

        return (Map<String, Object>) JSON.deserializeUntyped(httpResponse.getBody());
    }

    /**
     * Get Account List by given ID's
     *
     * @param AccountIdList list of AccountIds
     *
     * @return Account-Contact Json
     */
    public static List<Object> getAccountListV1(AccountIdList accountIdsList) {
        String responseBody = '';
        HttpResponse httpResponse = new UTLHttpRequestBuilder()
            .post(GRACE_CREDENTIAL + ACCOUNT_V1_LIST_PATH)
            .setHeader(API_KEY_HEADER, API_KEY)
            .json(accountIdsList)
            .send();

        if (httpResponse.getStatusCode() != 200)
            throw createGraceApiExeption(httpResponse);
            
        responseBody = httpResponse.getBody();

        return (List<Object>) JSON.deserializeUntyped(responseBody);
    }

    /**
     * CDC-Pattern to get the AccountIds on Change.
     * 
     * @param limitQueryParam the limit of records that will be returned
     *
     * @return Account list consisting only Core_Customer_Number__c field
     */
    public static List<Account> getCdcAccountIdsV1(Integer limitQueryParam) {
        String responseBody = '';
        String pathQuery = limitQueryParam == null ? '' : '?limit=' + limitQueryParam;

        HttpResponse httpResponse = new UTLHttpRequestBuilder()
                .get(GRACE_CREDENTIAL + CDC_ACCOUNT_IDs_V1_PATH + pathQuery)
                .setHeader(API_KEY_HEADER, API_KEY)
                .send();

        if (httpResponse.getStatusCode() != 200)
            throw createGraceApiExeption(httpResponse);

        responseBody = httpResponse.getBody();

        return (List<Account>) JSON.deserialize(responseBody, List<Account>.class);

    }

    /**
     * CDC-Pattern to get the next Accounts on Change.
     *
     * @param limitQueryParam the limit of records that will be returned
     *
     * @return Account-Contact Json
     */
    public static List<Object> getCdcAccountsV1(Integer limitQueryParam) {
        String responseBody = '';
        // TODO
        HttpResponse httpResponse = new UTLHttpRequestBuilder()
            .get(GRACE_CREDENTIAL + CDC_ACCOUNT_V1_PATH + '?limit=' + limitQueryParam)
            .setHeader(API_KEY_HEADER, API_KEY)
            .send();

        if (httpResponse.getStatusCode() != 200)
            throw createGraceApiExeption(httpResponse);

        responseBody = httpResponse.getBody();

        return (List<Object>) JSON.deserializeUntyped(responseBody);
    }

    /**
     * Get Account by accountId / Core Customer Number
     *
     * @param accountId
     *
     * @return single Account mapped by its AccountId
     */
    public static Map<String, Object> getAccountByAccountIdV1(String accountId) {
        return (Map<String, Object>) JSON.deserializeUntyped(getAccountByAccountIdRawV1(accountId));
    }

    /**
     * Get Account by the accountId / Core Customer Number
     *
     * @param accountId
     *
     * @return json Response
     */
    public static String getAccountByAccountIdRawV1(String accountId) {
        HttpResponse httpResponse = new UTLHttpRequestBuilder()
            .get(GRACE_CREDENTIAL + ACCOUNT_V1_PATH + '/byaccountid/' + accountId)
            .setHeader(API_KEY_HEADER, API_KEY)
            .send();

        if (httpResponse.getStatusCode() != 200)
            throw createGraceApiExeption(httpResponse);

        return httpResponse.getBody();
    }


    /**
     * Map postalCodes accordingly to create Json Body
     * 
     * @param postalCodes List of postalCodes to map
     * 
     * @return PostCodeWrapperRequest 
     */
    private static PostCodeWrapperRequest mapPostCodeRequest(List<String> postalCodes) {
        PostCodeWrapperRequest postCodeWrapperRequest = new PostCodeWrapperRequest();
        postCodeWrapperRequest.payload = new List<PostCodeRequest>();
        for (String postCode : postalCodes) {
            PostCodeRequest payload = new PostCodeRequest();
            payload.zip = postCode;
            postCodeWrapperRequest.payload.add(payload);
        }
        return postCodeWrapperRequest;
    }

    /**
     * Deserialize JSON-Obj
     *
     * @param jsonObj with gets deserialized to Map
     *
     * @return SalesUnits mapped by their Ids
     */
    private static Map<String, List<SalesUnit>> deserializeSalesUnitsByPostCodes(String jsonObj) {
        Map<String, List<SalesUnit>> salesUnitsbyPostCodes = new Map<String, List<SalesUnit>>();

        List<postCodeWrapper> salesUnits = (List<PostCodeWrapper>) JSON.deserialize(
            jsonObj,
            List<PostCodeWrapper>.class
        );

        for (PostCodeWrapper postCode : salesUnits) {
            salesUnitsbyPostCodes.put(postCode.zip, postCode.businessareas);
        }
        
        return salesUnitsbyPostCodes;
    }

    /**
     * Creates Grace API Exception with the given Error response.
     *
     * @param httpResponse the error Response
     *
     * @return created GraceAPIException
     */
    private static GraceAPIException createGraceApiExeption(HttpResponse httpResponse) {
        String responseBody = httpResponse.getBody();

        // deserialize error message in response
        String responseErrorMessage = null;
        if (!String.isEmpty(responseBody)) {
            Map<String, Object> errorBody = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            responseErrorMessage = (String) errorBody.get('message');
        }

        // format message
        String errorMessageTemplate = 'Grace-Api error-code: {0}. Error-message: "{1}".';
        String formatted = String.format(
            errorMessageTemplate,
            new List<Object>{
                httpResponse.getStatusCode(),
                !String.isEmpty(responseErrorMessage) ? responseErrorMessage : 'no error message present'
            }
        );
        return new GraceAPIException(formatted);
    }

    /**
     *  Account Id-List Request Object for Grace-API
     */
    public class AccountIdList {
        public AccountsId[] accounts;
    }

    /**
     *  Account Id Request Object for Grace-API
     */
    public class AccountsId {
        public String accountid;
    }

    /**
     * Territory-API JSON Response Obj
     */
    public class SalesUnit {
        /**
         * could be not present in non-id-mapped responses
         */
        public String salesforceid;
        public Integer businessarea;
        public String salesunitid;
        public String salesunit;
        public String region;
        public String regionname;
        public String companyid;
        public String company;
        public String businessareaname;
    }

    /**
     *  Territory-API JSON Request Obj
     */
    private class PostCodeWrapperRequest {
        public List<PostCodeRequest> payload;
    }

    /**
     *  Territory-API JSON Request Obj
     */
    private class PostCodeRequest {
        public String zip;
    }

    /**
     *  Territory-API JSON Return Obj
     */
    public class PostCodeWrapper {
        public String zip;
        public List<SalesUnit> businessareas;
    }

    public class GraceAPIException extends Exception {
    }

    @TestVisible
    private static Map<String, List<SalesUnit>> mockedSalesUnitsByPostalCodes;

    /**
     * Mocks SalesUnit with the setted SHRGraceAPI.mockedSalesUnitsByPostalCodes. This variable should match
     *
     * @param postalCodes postal codes mapped by account ids
     * @return generated SalesUnitList mapped by postcodes, SalesUnit should be present in mockedSalesUnitsByPostalCodes
     */
    private static Map<String, List<SalesUnit>> mockSalesUnitsByPostalCodes(List<String> postalCodes) {
      Map<String, List<SalesUnit>> salesUnitsbyPostCodes = new Map<String, List<SalesUnit>>();
        // In test Method not set.
        if (postalCodes == null)
            return new Map<String, List<SalesUnit>>();

        for (String postCode : postalCodes) {
            List<SalesUnit> salesUnitList = mockedSalesUnitsByPostalCodes.get(postCode);
            if (salesUnitList != null)
            salesUnitsbyPostCodes.put(postCode, salesUnitList);
        }
      return salesUnitsbyPostCodes;
    }
}