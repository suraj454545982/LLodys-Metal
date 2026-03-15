@IsTest
private class AccountUpdateOutboundCalloutToSAPTest {

    // --------------------------------------------------
    // HTTP MOCK
    // --------------------------------------------------
    private class UpdateMock implements HttpCalloutMock {
        private String mode;
        UpdateMock(String mode) { this.mode = mode; }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String ep = req.getEndpoint() == null ? '' : req.getEndpoint().toLowerCase();

            // Token
            if (ep.contains('token') || ep.contains('oauth')) {
                if (mode == 'tokenError') {
                    res.setStatusCode(500);
                    res.setBody('Token error');
                    return res;
                }
                res.setStatusCode(200);
                res.setBody('{"access_token":"mock_token"}');
                return res;
            }

            // Update API
            if (mode == 'updateFail') {
                res.setStatusCode(400);
                res.setBody('Update failed');
                return res;
            }

            res.setStatusCode(200);
            res.setBody('{"status":"ok"}');
            return res;
        }
    }

    // --------------------------------------------------
    // SUCCESS FLOW
    // --------------------------------------------------
    @IsTest
    static void testUpdateSuccess() {

        Account acc = new Account(
            Name = 'UpdateSuccess',
            SAP_Customer_Code__c = 'CUST1',
            BillingCountry = 'United Kingdom',
            Phone = '9999999999'
        );
        insert acc;

        Test.setMock(HttpCalloutMock.class, new UpdateMock('success'));

        Test.startTest();
        Database.executeBatch(
            new AccountUpdateOutboundCalloutToSAP(new Set<Id>{ acc.Id }),
            200
        );
        Test.stopTest();

        Account updated = [
            SELECT Needs_Sensitive_Field_Check__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(
            false,
            updated.Needs_Sensitive_Field_Check__c,
            'Flag should be cleared on success'
        );

        System.assert(
            [SELECT COUNT() FROM API_LOG__c] > 0,
            'API logs must be created'
        );
    }

    // --------------------------------------------------
    // TOKEN FAILURE FLOW
    // --------------------------------------------------
    @IsTest
    static void testTokenFailure() {

        Account acc = new Account(
            Name = 'TokenFail',
            SAP_Customer_Code__c = 'CUST2',
            BillingCountry = 'United Kingdom',
            Phone = '8888888888'
        );
        insert acc;

        Test.setMock(HttpCalloutMock.class, new UpdateMock('tokenError'));

        Test.startTest();
        Database.executeBatch(
            new AccountUpdateOutboundCalloutToSAP(new Set<Id>{ acc.Id }),
            200
        );
        Test.stopTest();

        Account unchanged = [
            SELECT Needs_Sensitive_Field_Check__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        

        
    }

    // --------------------------------------------------
    // UPDATE FAILURE FLOW
    // --------------------------------------------------
    @IsTest
    static void testUpdateFailure() {

        Account acc = new Account(
            Name = 'UpdateFail',
            SAP_Customer_Code__c = 'CUST3',
            BillingCountry = 'United Kingdom',
            Phone = '7777777777'
        );
        insert acc;

        Test.setMock(HttpCalloutMock.class, new UpdateMock('updateFail'));

        Test.startTest();
        Database.executeBatch(
            new AccountUpdateOutboundCalloutToSAP(new Set<Id>{ acc.Id }),
            200
        );
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM API_LOG__c] > 0,
            'Update failure must be logged'
        );
    }
}