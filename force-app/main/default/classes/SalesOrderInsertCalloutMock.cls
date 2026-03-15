@IsTest
global class SalesOrderInsertCalloutMock implements HttpCalloutMock {

    global HTTPResponse respond(HTTPRequest req) {

        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');

        // 🔑 TOKEN CALLOUT
        if (req.getEndpoint().contains('token')) {
            res.setStatusCode(200);
            res.setBody(
                '{' +
                '  "access_token": "dummy-access-token",' +
                '  "token_type": "Bearer",' +
                '  "expires_in": 3600' +
                '}'
            );
            return res;
        }

        // 🔑 SALES ORDER INSERT CALLOUT
        if (req.getMethod() == 'POST') {
            res.setStatusCode(201);
            res.setBody(
                '{' +
                '  "SalesOrder_Res": {' +
                '    "Sale_order_number": "SAP-ORDER-9999"' +
                '  }' +
                '}'
            );
            return res;
        }

        // Fallback
        res.setStatusCode(400);
        res.setBody('{"error":"Unexpected callout"}');
        return res;
    }
}