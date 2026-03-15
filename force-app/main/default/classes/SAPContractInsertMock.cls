@IsTest
global class SAPContractInsertMock implements HttpCalloutMock {

    global HTTPResponse respond(HTTPRequest req) {

        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');

        // TOKEN CALL
        if (req.getEndpoint().contains('token')) {
            res.setStatusCode(200);
            res.setBody('{"access_token":"dummy_token"}');
            return res;
        }

        // CONTRACT INSERT CALL
        res.setStatusCode(201);
        res.setBody(
            '{ "SalesContract_Res": [ { "Contact_Number": "SAP123456" } ] }'
        );
        return res;
    }
}