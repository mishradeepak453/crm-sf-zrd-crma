/**
 * HttpRequestBuilder
 *
 * <href a="">
 * <a href="https://github.com/adtennant/apex-http-request-builder/blob/master/src/classes/HttpRequestBuilder.cls">
 *     apex-http-request-builder
 * </a>
 *
 * @author  daniel.gette@zeppelin.com
 *
 */
public without sharing class UTLHttpRequestBuilder
{
    /**
     * @description The Content-Type header key.
     */
    public static final String CONTENT_TYPE_HEADER = 'Content-Type';

    /**
     * @description The Content-Type value for application/json.
     */
    public static final String CONTENT_TYPE_APPLICATION_JSON = 'application/json';

    /**
     * @description The HTTP verb for GET.
     */
    public static final String HTTP_METHOD_GET = 'GET';

    /**
     * @description The HTTP verb for PATCH.
     */
    public static final String HTTP_METHOD_PATCH = 'PATCH';

    /**
     * @description The HTTP verb for POST.
     */
    public static final String HTTP_METHOD_POST = 'POST';

    /**
     * @description The HTTP verb for PUT.
     */
    public static final String HTTP_METHOD_PUT = 'PUT';

    /**
     * @description The request body.
     */
    private String body;

    /**
     * @description The request body as a Blob.
     */
    private Blob bodyAsBlob;

    /**
     * @description The request body as a DOM Document.
     */
    private Dom.Document bodyDocument;

    /**
     * @description The developer name of the client certificate.
     */
    private String certDevName;

    /**
     * @description If true, the data in the body is delivered to the endpoint in the gzip compressed format. If false, no compression format is used.
     */
    private Boolean flag;

    /**
     * @description The endpoint
     */
    private String endpoint;

    /**
     * @description Map of headers.
     */
    private Map<String, String> headers = new Map<String, String>();

    /**
     * @description The HTTP method.
     */
    private String method;

    /**
     * @description The timeout in miliseconds.
     */
    private Integer timeout;

    /**
     * @description Build a new client request.
     * @return HttpRequestBuilder New instance of HttpRequest.
     */
    public HttpRequest build()
    {
        return build(new List<String>());
    }

    /**
     * @description Build a new client request with the given parameters substituted within the endpoint.
     * @param params The parameters to substitute within the endpoint.
     * @return HttpRequestBuilder New instance of HttpRequest.
     */
    public HttpRequest build(List<String> params)
    {
        HttpRequest req = new HttpRequest();

        if(body != null)
        {
            req.setBody(body);
        }

        if(bodyAsBlob != null)
        {
            req.setBodyAsBlob(bodyAsBlob);
        }

        if(bodyDocument != null)
        {
            req.setBodyDocument(bodyDocument);
        }

        if(certDevName != null)
        {
            req.setClientCertificateName(certDevName);
        }

        if(flag != null)
        {
            req.setCompressed(flag);
        }

        if(endpoint != null)
        {
            req.setEndpoint(String.format(endpoint, params));
        }

        for(String key : headers.keySet())
        {
            req.setHeader(key, headers.get(key));
        }

        if(method != null)
        {
            req.setMethod(method);
        }

        if(timeout != null)
        {
            req.setTimeout(timeout);
        }

        return req;
    }

    /**
     * @description Sends the request and returns the response.
     * @return HttpResponse The response.
     */
    public HttpResponse send()
    {
        return send(new List<String>());
    }

    /**
     * @description Sends the request with the given parameters substituted within the endpoint and returns the response.
     * @param params The parameters to substitute within the endpoint.
     * @return HttpResponse The response.
     */
    public HttpResponse send(List<String> params)
    {
        return new Http().send(build(params));
    }

    /**
     * @description Sets the type of method to be used for the HTTP request to GET and specifies the endpoint for this request.
     * @param endpoint The endpoint.
     * @return HttpRequestBuilder The updated request builder.
     */
    public UTLHttpRequestBuilder get(String endpoint)
    {
        return setMethod(HTTP_METHOD_GET).setEndpoint(endpoint);
    }

    /**
     * @description Sets the type of method to be used for the HTTP request to PATCH and specifies the endpoint for this request.
     * @param endpoint The endpoint.
     * @return UTLHttpRequestBuilder The updated request builder.
     */
    public UTLHttpRequestBuilder patch(String endpoint)
    {
        return setMethod(HTTP_METHOD_PATCH).setEndpoint(endpoint);
    }

    /**
     * @description Sets the type of method to be used for the HTTP request to POST and specifies the endpoint for this request.
     * @param endpoint The endpoint.
     * @return UTLHttpRequestBuilder The updated request builder.
     */
    public UTLHttpRequestBuilder post(String endpoint)
    {
        return setMethod(HTTP_METHOD_POST).setEndpoint(endpoint);
    }

    /**
     * @description Sets the type of method to be used for the HTTP request to PUT and specifies the endpoint for this request.
     * @param endpoint The endpoint.
     * @return UTLHttpRequestBuilder The updated request builder.
     */
    public UTLHttpRequestBuilder put(String endpoint)
    {
        return setMethod(HTTP_METHOD_PUT).setEndpoint(endpoint);
    }

    /**
     * @description Sets the contents of the body for this request. The contents are serialized as JSON.
     * @param data The data to be serialized as the body.
     * @return UTLHttpRequestBuilder The updated request builder.
     */
    public UTLHttpRequestBuilder json(Object data)
    {
        return setHeader(CONTENT_TYPE_HEADER, CONTENT_TYPE_APPLICATION_JSON).setBody(JSON.serialize(data));
    }

    /**
     * @description Sets the contents of the body for this request.
     * @param body The body.
     * @return UTLHttpRequestBuilder The updated request builder.
     */
    public UTLHttpRequestBuilder setBody(String body)
    {
        this.body = body;
        return this;
    }

    /**
     * @description Sets the contents of the body for this request using a Blob.
     * @param body The body as a Blob.
     * @return UTLHttpRequestBuilder The updated request builder.
     */
    public UTLHttpRequestBuilder setBody(Blob body)
    {
        this.bodyAsBlob = body;
        return this;
    }

    /**
     * @description Sets the contents of the body for this request. The contents represent a DOM document.
     * @param body The body as a DOM document.
     * @return UTLHttpRequestBuilder The updated request builder.
     */
    public UTLHttpRequestBuilder setBody(Dom.Document document)
    {
        this.bodyDocument = document;
        return this;
    }

    /**
     * @description If the external service requires a client certificate for authentication, set the certificate name.
     * @param certDevName The certificate name.
     * @return UTLHttpRequestBuilder The updated request builder.
     */
    public UTLHttpRequestBuilder setClientCertificateName(String certDevName)
    {
        this.certDevName = certDevName;
        return this;
    }

    /**
     * @description If true, the data in the body is delivered to the endpoint in the gzip compressed format. If false, no compression format is used.
     * @param flag true if the data in the body is delivered to the endpoint in the gzip compressed format, otherwise false.
     * @return UTLHttpRequestBuilder The updated request builder.
     */
    public UTLHttpRequestBuilder setCompressed(Boolean flag)
    {
        this.flag = flag;
        return this;
    }

    /**
     * @description Specifies the endpoint for this request.
     * @param endpoint The endpoint.
     * @return UTLHttpRequestBuilder The updated request builder.
     */
    public UTLHttpRequestBuilder setEndpoint(String endpoint)
    {
        this.endpoint = endpoint;
        return this;
    }

    /**
     * @description Sets the contents of the request header.
     * @param key The header.
     * @param value The value for the header.
     * @return UTLHttpRequestBuilder The updated request builder.
     */
    public UTLHttpRequestBuilder setHeader(String key, String value)
    {
        this.headers.put(key, value);
        return this;
    }

    /**
     * @description Sets the contents of multiple request headers.
     * @param headers Map of headers.
     * @return UTLHttpRequestBuilder The updated request builder.
     */
    public UTLHttpRequestBuilder setHeaders(Map<String, String> headers)
    {
        this.headers.putAll(headers);
        return this;
    }

    /**
     * @description Sets the type of method to be used for the HTTP request.
     * @param method The HTTP method,
     * @return UTLHttpRequestBuilder The updated request builder.
     */
    public UTLHttpRequestBuilder setMethod(String method)
    {
        this.method = method;
        return this;
    }

    /**
     * @description Sets the timeout in milliseconds for the request.
     * @param timeout The timeout in miliseconds.
     * @return UTLHttpRequestBuilder The updated request builder.
     */
    public UTLHttpRequestBuilder setTimeout(Integer timeout)
    {
        this.timeout = timeout;
        return this;
    }
}