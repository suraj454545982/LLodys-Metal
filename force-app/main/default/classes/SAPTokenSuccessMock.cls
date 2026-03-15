@IsTest
global class SAPTokenSuccessMock implements HttpCalloutMock {
    global HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"access_token":"TEST_ACCESS_TOKEN"}');
        return res;
    }
}