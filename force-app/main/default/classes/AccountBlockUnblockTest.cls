@isTest
private class AccountBlockUnblockTest {

    /**
     * Utility to prepare REST context
     */
    private static void prepareRestContext(String body) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/customer/block/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = res;
    }

    @isTest
    static void testBlockUnblockAccountsAllScenarios() {

        /* ---------------------------------
           Create Accounts for testing
        ----------------------------------*/
        Account acc1 = new Account(
            Name = 'Test Account 1',
            SAP_Customer_Code__c = 'SAP001',
            Customer_Blocked__c = 'No',
            Phone='9876543210'
        );

        Account acc2 = new Account(
            Name = 'Test Account 2',
            SAP_Customer_Code__c = 'SAP002',
            Customer_Blocked__c = 'Yes',
            Phone = '9812356703'
        );

        insert new List<Account>{ acc1, acc2 };

        /* ---------------------------------
           Build request payload
           Covers:
           - Valid block
           - Valid unblock
           - Duplicate SAP
           - Invalid Account_Blocked
           - Missing SAP
           - Account not found
        ----------------------------------*/
        String requestJson = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'SAP_Account_Number' => 'SAP001',
                'Account_Blocked' => 'Yes'
            },
            new Map<String, Object>{
                'SAP_Account_Number' => 'SAP002',
                'Account_Blocked' => 'No'
            },
            new Map<String, Object>{
                'SAP_Account_Number' => 'SAP001',
                'Account_Blocked' => 'Yes'
            },
            new Map<String, Object>{
                'SAP_Account_Number' => 'SAP003',
                'Account_Blocked' => 'Yes'
            },
            new Map<String, Object>{
                'SAP_Account_Number' => '',
                'Account_Blocked' => 'Yes'
            },
            new Map<String, Object>{
                'SAP_Account_Number' => 'SAP004',
                'Account_Blocked' => 'INVALID'
            }
        });

        prepareRestContext(requestJson);

        /* ---------------------------------
           Execute REST method
        ----------------------------------*/
        Test.startTest();
        List<AccountBlockUnblock.ResponseWrapper> responses =
            AccountBlockUnblock.blockUnblockAccounts();
        Test.stopTest();

        /* ---------------------------------
           Verify Accounts updated
        ----------------------------------*/
        Map<Id, Account> refreshed = new Map<Id, Account>(
            [SELECT Customer_Blocked__c FROM Account WHERE Id IN :new List<Id>{ acc1.Id, acc2.Id }]
        );

        System.assertEquals(
            'Yes',
            refreshed.get(acc1.Id).Customer_Blocked__c,
            'Account 1 should be blocked'
        );

        System.assertEquals(
            'No',
            refreshed.get(acc2.Id).Customer_Blocked__c,
            'Account 2 should be unblocked'
        );

        /* ---------------------------------
           Verify API_LOG__c created
        ----------------------------------*/
        API_LOG__c log = [
            SELECT Id, Status__c, Request__c, Response__c, Status_Code__c
            FROM API_LOG__c
            LIMIT 1
        ];

        System.assertEquals('200', log.Status_Code__c);
        System.assertNotEquals(null, log.Request__c);
        System.assertNotEquals(null, log.Response__c);

        /* ---------------------------------
           Basic response sanity
        ----------------------------------*/
        System.assert(responses.size() > 0, 'Responses should be returned');
    }

    @isTest
    static void testEmptyRequestBody() {

        prepareRestContext('');

        Test.startTest();
        List<AccountBlockUnblock.ResponseWrapper> responses =
            AccountBlockUnblock.blockUnblockAccounts();
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals('false', responses[0].success);
    }
    
    
    
}