@IsTest
private class AccountInsertOutboundCalloutToSAPTest {

    // --------------------------------------------------
    // HTTP MOCK
    // --------------------------------------------------
    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();

            if (req.getEndpoint().toLowerCase().contains('token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"mock_token"}');
                return res;
            }

            res.setStatusCode(201);
            res.setBody('{"Customer":"CUST123"}');
            return res;
        }
    }

    // --------------------------------------------------
    // SINGLE BATCH EXECUTION — SAFE
    // --------------------------------------------------
    @IsTest
    static void testAccountInsertBatch() {

        // ---- Test Account ----
        Account acc = new Account(
            Name = 'SAP Account',
            Phone = '9999999999',
            BillingCountry = 'India'
        );
        insert acc;

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();

        // 🔑 batchSize MUST be >= record count
        Database.executeBatch(
            new AccountInsertOutboundCalloutToSAP(new Set<Id>{ acc.Id }),
            200
        );

        Test.stopTest();

        // ---- Assertions ----
        Account updated = [
            SELECT SAP_Customer_Code__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(
            'CUST123',
            updated.SAP_Customer_Code__c,
            'SAP customer code must be updated'
        );

        System.assert(
            [SELECT COUNT() FROM API_LOG__c] > 0,
            'API logs must be created'
        );
    }
}