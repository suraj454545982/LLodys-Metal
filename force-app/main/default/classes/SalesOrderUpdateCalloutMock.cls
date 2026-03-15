@IsTest
global class SalesOrderUpdateCalloutMock implements HttpCalloutMock {

    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);
        res.setBody('{"status":"SUCCESS"}');
        return res;
    }
}