/**
 * UTLMockHttpResponse Helper Class
 *
 * <href a="">
 * <a href="https://github.com/dcstuff/MockHttpResponse/blob/master/classes/MockHttpResponse.cls">
 *     MockHttpResponse
 * </a>
 *
 * @author  daniel.gette@zeppelin.com
 *
 */
@IsTest
public class UTLMockHttpResponse implements HttpCalloutMock {
    static List<Mock> mocks;

    public static UTLMockHttpResponse builder() {
        mocks = new List<Mock>{ new Mock() };
        return new UTLMockHttpResponse();
    }

    public static UTLMockHttpResponse emptyBuilder() {
        mocks = new List<Mock>();
        return new UTLMockHttpResponse();
    }

    public UTLMockHttpResponse next() {
        mocks.add(new Mock());
        return this;
    }

    public UTLMockHttpResponse mockCalloutException(String exceptionMessage) {
        mocks.add(new Mock(exceptionMessage));
        return this;
    }

    public UTLMockHttpResponse statusCode(Integer statusCode) {
        getCurrentResponse().setStatusCode(statusCode);
        return this;
    }

    public UTLMockHttpResponse status(String status) {
        getCurrentResponse().setStatus(status);
        return this;
    }

    public UTLMockHttpResponse contentType(String contentType) {
        getCurrentResponse().setHeader('Content-Type', contentType);
        return this;
    }

    public UTLMockHttpResponse body(String body) {
        getCurrentResponse().setBody(body);
        return this;
    }
    
    public UTLMockHttpResponse body(Map<String, Object> body) {
        getCurrentResponse().setBody(JSON.serialize(body));
        return this;
    }

    public HttpResponse respond(HttpRequest req) {
        Mock m = mocks.remove(0);

        if (m.isException) {
            CalloutException e = (CalloutException) CalloutException.class
                    .newInstance();
            if (m.exceptionMessage != null) {
                e.setMessage(m.exceptionMessage);
            }
            throw e;
        }

        return m.res;
    }

    static HttpResponse getCurrentResponse() {
        return mocks[mocks.size() - 1].res;
    }

    class Mock {
        HttpResponse res;
        Boolean isException;
        String exceptionMessage;

        Mock() {
            res = new HttpResponse();
            res.setStatusCode(200);
            isException = false;
        }

        Mock(String exceptionMessage) {
            this.exceptionMessage = exceptionMessage;
            isException = true;
        }
    }
}