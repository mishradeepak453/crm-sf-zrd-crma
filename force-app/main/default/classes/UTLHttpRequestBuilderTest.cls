/**
 * TriggerHandler
 *
 * <href a="">
 * <a href="https://github.com/adtennant/apex-http-request-builder/blob/master/src/classes/HttpRequestBuilderTest.cls">
 *     apex-http-request-builder
 * </a>
 *
 * @author  daniel.gette@zeppelin.com
 *
 */
@isTest
private class UTLHttpRequestBuilderTest
{
    private static final String BODY = 'test';
    private static final Blob BODY_BLOB = Blob.valueOf('test');
    private static final Dom.Document BODY_DOCUMENT = new DOM.Document();

    static
    {
        BODY_DOCUMENT.createRootElement('Envelope', 'http://schemas.xmlsoap.org/soap/envelope/', 'soapenv');
    }

    private static final Boolean FLAG = true;

    private static final String ENDPOINT = 'https://www.example.com/{0}/{1}';

    private static final String HEADER_KEY = UTLHttpRequestBuilder.CONTENT_TYPE_HEADER;
    private static final String HEADER_VALUE = UTLHttpRequestBuilder.CONTENT_TYPE_APPLICATION_JSON;

    private static final Map<String, String> HEADERS = new Map<String, String> {
            'Accept' => 'application/xml'
    };

    private static final String METHOD = UTLHttpRequestBuilder.HTTP_METHOD_POST;

    private static final List<String> PARAMS = new List<String> { 'param1' , 'param2' };

    @isTest
    private static void itShoulBuildARequest()
    {
        HttpRequest result = new UTLHttpRequestBuilder()
                .setBody(BODY)
                .setCompressed(FLAG)
                .setEndpoint(ENDPOINT)
                .setHeader(UTLHttpRequestBuilder.CONTENT_TYPE_HEADER, UTLHttpRequestBuilder.CONTENT_TYPE_APPLICATION_JSON)
                .setHeaders(HEADERS)
                .setMethod(METHOD)
                .build();

        System.assertEquals(BODY, result.getBody());
        System.assertEquals(FLAG, result.getCompressed());
        System.assertEquals(ENDPOINT, result.getEndpoint());
        System.assertEquals(UTLHttpRequestBuilder.CONTENT_TYPE_APPLICATION_JSON, result.getHeader(UTLHttpRequestBuilder.CONTENT_TYPE_HEADER));

        for(String key : HEADERS.keySet())
        {
            System.assertEquals(HEADERS.get(key), result.getHeader(key));
        }

        System.assertEquals(METHOD, result.getMethod());
    }

    @isTest
    private static void itShouldBuildARequestWithParams()
    {
        HttpRequest result = new UTLHttpRequestBuilder()
                .setBody(BODY)
                .setCompressed(FLAG)
                .setEndpoint(ENDPOINT)
                .setHeader(UTLHttpRequestBuilder.CONTENT_TYPE_HEADER, UTLHttpRequestBuilder.CONTENT_TYPE_APPLICATION_JSON)
                .setHeaders(HEADERS)
                .setMethod(METHOD)
                .build(PARAMS);

        System.assertEquals(BODY, result.getBody());
        System.assertEquals(FLAG, result.getCompressed());
        System.assertEquals(String.format(ENDPOINT, PARAMS), result.getEndpoint());
        System.assertEquals(UTLHttpRequestBuilder.CONTENT_TYPE_APPLICATION_JSON, result.getHeader(UTLHttpRequestBuilder.CONTENT_TYPE_HEADER));

        for(String key : HEADERS.keySet())
        {
            System.assertEquals(HEADERS.get(key), result.getHeader(key));
        }

        System.assertEquals(METHOD, result.getMethod());
    }

    private class UTLHttpRequestBuilderMock implements HttpCalloutMock
    {
        private final List<String> params;

        private UTLHttpRequestBuilderMock()
        {
            this(new List<String>());
        }

        private UTLHttpRequestBuilderMock(List<String> params)
        {
            this.params = params;
        }

        public HttpResponse respond(HttpRequest request)
        {
            System.assertEquals(BODY, request.getBody());
            System.assertEquals(FLAG, request.getCompressed());
            System.assertEquals(String.format(ENDPOINT, this.params), request.getEndpoint());
            System.assertEquals(UTLHttpRequestBuilder.CONTENT_TYPE_APPLICATION_JSON, request.getHeader(UTLHttpRequestBuilder.CONTENT_TYPE_HEADER));

            for(String key : HEADERS.keySet())
            {
                System.assertEquals(HEADERS.get(key), request.getHeader(key));
            }

            System.assertEquals(METHOD, request.getMethod());

            return new HttpResponse();
        }
    }

    @isTest
    private static void itShoulSendARequest()
    {
        Test.setMock(HttpCalloutMock.class, new UTLHttpRequestBuilderMock());

        HttpResponse result = new UTLHttpRequestBuilder()
                .setBody(BODY)
                .setCompressed(FLAG)
                .setEndpoint(ENDPOINT)
                .setHeader(UTLHttpRequestBuilder.CONTENT_TYPE_HEADER, UTLHttpRequestBuilder.CONTENT_TYPE_APPLICATION_JSON)
                .setHeaders(HEADERS)
                .setMethod(METHOD)
                .send();

        System.assertNotEquals(null, result);
    }

    @isTest
    private static void itShouldSendARequestWithParams()
    {
        Test.setMock(HttpCalloutMock.class, new UTLHttpRequestBuilderMock(PARAMS));

        HttpResponse result = new UTLHttpRequestBuilder()
                .setBody(BODY)
                .setCompressed(FLAG)
                .setEndpoint(ENDPOINT)
                .setHeader(UTLHttpRequestBuilder.CONTENT_TYPE_HEADER, UTLHttpRequestBuilder.CONTENT_TYPE_APPLICATION_JSON)
                .setHeaders(HEADERS)
                .setMethod(METHOD)
                .send(PARAMS);

        System.assertNotEquals(null, result);
    }

    @isTest
    private static void itShouldCreateAGETRequest()
    {
        HttpRequest result = new UTLHttpRequestBuilder()
                .get(ENDPOINT)
                .build();

        System.assertEquals(UTLHttpRequestBuilder.HTTP_METHOD_GET, result.getMethod());
        System.assertEquals(ENDPOINT, result.getEndpoint());
    }

    @isTest
    private static void itShouldCreateAPATCHRequest()
    {
        HttpRequest result = new UTLHttpRequestBuilder()
                .patch(ENDPOINT)
                .build();

        System.assertEquals(UTLHttpRequestBuilder.HTTP_METHOD_PATCH, result.getMethod());
        System.assertEquals(ENDPOINT, result.getEndpoint());
    }

    @isTest
    private static void itShouldCreateAPOSTRequest()
    {
        HttpRequest result = new UTLHttpRequestBuilder()
                .post(ENDPOINT)
                .build();

        System.assertEquals(UTLHttpRequestBuilder.HTTP_METHOD_POST, result.getMethod());
        System.assertEquals(ENDPOINT, result.getEndpoint());
    }

    @isTest
    private static void itShouldCreateAPUTRequest()
    {
        HttpRequest result = new UTLHttpRequestBuilder()
                .put(ENDPOINT)
                .build();

        System.assertEquals(UTLHttpRequestBuilder.HTTP_METHOD_PUT, result.getMethod());
        System.assertEquals(ENDPOINT, result.getEndpoint());
    }

    @isTest
    private static void itShouldCreateAJSONRequest()
    {
        HttpRequest result = new UTLHttpRequestBuilder()
                .json(PARAMS)
                .build();

        System.assertEquals(UTLHttpRequestBuilder.CONTENT_TYPE_APPLICATION_JSON, result.getHeader(UTLHttpRequestBuilder.CONTENT_TYPE_HEADER));
        System.assertEquals(JSON.serialize(PARAMS), result.getBody());
    }

    @isTest
    private static void itShouldSetBody()
    {
        HttpRequest result = new UTLHttpRequestBuilder()
                .setBody(BODY)
                .build();

        System.assertEquals(BODY, result.getBody());
    }

    @isTest
    private static void itShouldSetBodyAsBlob()
    {
        HttpRequest result = new UTLHttpRequestBuilder()
                .setBody(BODY_BLOB)
                .build();

        System.assertEquals(BODY_BLOB, result.getBodyAsBlob());
    }

    @isTest
    private static void itShouldSetBodyDocument()
    {
        HttpRequest result = new UTLHttpRequestBuilder()
                .setBody(BODY_DOCUMENT)
                .build();

        System.assertEquals(BODY_DOCUMENT, result.getBodyDocument());
    }

    @isTest
    private static void itShouldSetCompressed()
    {
        HttpRequest result = new UTLHttpRequestBuilder()
                .setCompressed(FLAG)
                .build();

        System.assertEquals(FLAG, result.getCompressed());
    }

    @isTest
    private static void itShouldSetEndpoint()
    {
        HttpRequest result = new UTLHttpRequestBuilder()
                .setEndpoint(ENDPOINT)
                .build();

        System.assertEquals(ENDPOINT, result.getEndpoint());
    }

    @isTest
    private static void itShouldSetHeader()
    {
        final String KEY = 'Accept';
        final String VALUE = 'application/xml';

        HttpRequest result = new UTLHttpRequestBuilder()
                .setHeader(HEADER_KEY, HEADER_VALUE)
                .build();

        System.assertEquals(HEADER_VALUE, result.getHeader(HEADER_KEY));
    }

    @isTest
    private static void itShouldSetHeaders()
    {
        HttpRequest result = new UTLHttpRequestBuilder()
                .setHeaders(HEADERS)
                .build();

        for(String key : HEADERS.keySet())
        {
            System.assertEquals(HEADERS.get(key), result.getHeader(key));
        }
    }

    @isTest
    private static void itShouldSetMethod()
    {
        HttpRequest result = new UTLHttpRequestBuilder()
                .setMethod(METHOD)
                .build();

        System.assertEquals(METHOD, result.getMethod());
    }
}