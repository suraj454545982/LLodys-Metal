@IsTest
global class SAPTokenFailureMock implements HttpCalloutMock {
    global HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(400);
        res.setBody('{"error":"invalid_client"}');
        return res;
    }
}