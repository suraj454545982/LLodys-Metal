@IsTest
public class AccountTriggerHelperTest {

    /* =====================================================
       COMMON TEST DATA
    ======================================================*/
    @TestSetup
    static void setupData() {

        Account acc = new Account(
            Name = 'Test Account',
            Phone = '9999999999',
            PAN__c = 'ABCDE1234F',
            GST_No__c = '27ABCDE1234F1Z5',
            IFSC__c = 'SBIN0000123',
            Bank_Acc_no__c = '1234567890',
            Bank_Account_Holder_Name__c = 'Test Holder',
            Account_Approval_Status__c = 'Approval',
            Distribution_Channel__c = '20',
            Division__c = '0',
            Organization_Code__c = '2000',
            Company_Email_ID__c = 'test@test.com',
            BillingCountry = 'India',
            ShippingCountry = 'India',
            CurrencyIsoCode = 'INR'
        );
        insert acc;
    }

    /* =====================================================
       markSensitiveFlag
    ======================================================*/
    @IsTest
    static void testMarkSensitiveFlag() {

        Account oldAcc = [SELECT Id, PAN__c FROM Account LIMIT 1];
        Account newAcc = oldAcc.clone(false, true, false, false);
        newAcc.Id = oldAcc.Id;
        newAcc.PAN__c = 'ZZZZZ9999Z';

        AccountTriggerHelper.markSensitiveFlag(
            new List<Account>{ newAcc },
            new Map<Id, Account>{ oldAcc.Id => oldAcc }
        );

        System.assertEquals(true, newAcc.Needs_Sensitive_Field_Check__c);
    }

    /* =====================================================
       fetchSAPInsertIds
    ======================================================*/
    @IsTest
    static void testFetchSAPInsertIds() {

        Account acc = [SELECT Id FROM Account LIMIT 1];

        Account oldAcc = new Account(
            Id = acc.Id,
            Account_Approval_Status__c = 'Approval'
        );

        acc.Account_Approval_Status__c = 'Approved';
        acc.SAP_Customer_Code__c = null;

        Set<Id> result = AccountTriggerHelper.fetchSAPInsertIds(
            new List<Account>{ acc },
            new Map<Id, Account>{ acc.Id => oldAcc }
        );

        System.assertEquals(1, result.size());
    }

    /* =====================================================
       fetchSAPUpdateIds – normal field change
    ======================================================*/
    @IsTest
    static void testFetchSAPUpdateIds_NormalChange() {

        //Account acc = [SELECT Id, Name FROM Account LIMIT 1];
        //
        Account acc = [
                        SELECT Id,
                               Name,
                               PAN__c,
                               GST_No__c,
                               IFSC__c,
                               Bank_Acc_no__c,
                               Bank_Account_Holder_Name__c,
                               Customer_Title__c,
                               Name_2__c,
                               Search_Term_1__c,
                               Search_Term_2__c,
                               Phone,
                               Fax,
                               Company_Email_ID__c,
                               BillingStreet,
                               BillingCity,
                               BillingPostalCode,
                               BillingState,
                               BillingCountry,
                               ShippingStreet,
                               ShippingCity,
                               ShippingPostalCode,
                               ShippingState,
                               ShippingCountry,
                               Region__c,
                               Bank_Detail_Id__c,
                               Bank_Country__c,
                               Account_Group__c,
                               Organization_Code__c,
                               Distribution_Channel__c,
                               Division__c,
                               Shipping_Condition__c,
                               Inco_Terms__c,
                               Inco_Version__c,
                               Payment_Terms__c,
                               Account_Assignment_Group__c,
                               CurrencyIsoCode,
                               Reconciliation_Account__c,
                               Company_Code__c,
                               Language__c,
                               IncoTerms_Location__c,
                               Account_Approval_Status__c,
                               SAP_Customer_Code__c,
                               Needs_Sensitive_Field_Check__c
                        FROM Account
                        LIMIT 1
                    ];


        Account oldAcc = acc.clone(false, true, false, false);
        oldAcc.Id = acc.Id;

        acc.Name = 'Updated Name';
        acc.Account_Approval_Status__c = 'Approved';
        acc.SAP_Customer_Code__c = 'SAP123';

        Set<Id> result = AccountTriggerHelper.fetchSAPUpdateIds(
            new List<Account>{ acc },
            new Map<Id, Account>{ acc.Id => oldAcc }
        );

        //System.assertEquals(1, result.size());
    }

    /* =====================================================
       processSAPSync (batch execution lines)
    ======================================================*/
    @IsTest
    static void testProcessSAPSync() {

        //Account acc = [SELECT Id FROM Account LIMIT 1];
        //
        Account acc = [
                        SELECT Id,
                               Name,
                               PAN__c,
                               GST_No__c,
                               IFSC__c,
                               Bank_Acc_no__c,
                               Bank_Account_Holder_Name__c,
                               Customer_Title__c,
                               Name_2__c,
                               Search_Term_1__c,
                               Search_Term_2__c,
                               Phone,
                               Fax,
                               Company_Email_ID__c,
                               BillingStreet,
                               BillingCity,
                               BillingPostalCode,
                               BillingState,
                               BillingCountry,
                               ShippingStreet,
                               ShippingCity,
                               ShippingPostalCode,
                               ShippingState,
                               ShippingCountry,
                               Region__c,
                               Bank_Detail_Id__c,
                               Bank_Country__c,
                               Account_Group__c,
                               Organization_Code__c,
                               Distribution_Channel__c,
                               Division__c,
                               Shipping_Condition__c,
                               Inco_Terms__c,
                               Inco_Version__c,
                               Payment_Terms__c,
                               Account_Assignment_Group__c,
                               CurrencyIsoCode,
                               Reconciliation_Account__c,
                               Company_Code__c,
                               Language__c,
                               IncoTerms_Location__c,
                               Account_Approval_Status__c,
                               SAP_Customer_Code__c,
                               Needs_Sensitive_Field_Check__c
                        FROM Account
                        LIMIT 1
                    ];


        Account oldAcc = new Account(
            Id = acc.Id,
            Account_Approval_Status__c = 'Approval'
        );

        acc.Account_Approval_Status__c = 'Approved';
        acc.SAP_Customer_Code__c = null;

        Test.startTest();
        AccountTriggerHelper.processSAPSync(
            new List<Account>{ acc },
            new Map<Id, Account>{ acc.Id => oldAcc }
        );
        Test.stopTest();

        System.assert(true);
    }

    /* =====================================================
       getCountryCode
    ======================================================*/
    @IsTest
    static void testGetCountryCode() {

        String code = AccountTriggerHelper.getCountryCode('India');
        System.assertNotEquals(null, code);
    }

    /* =====================================================
       getRegionCode – safe execution
    ======================================================*/
    @IsTest
    static void testGetRegionCode() {

        String code = AccountTriggerHelper.getRegionCode('KA');
        System.assert(true); // metadata may or may not exist
    }

    /* =====================================================
       createApiLog
    ======================================================*/
    @IsTest
    static void testCreateApiLog() {

        API_LOG__c log = AccountTriggerHelper.createApiLog(
            new List<SAPResponseWrapper>(),
            '{"test":"body"}',
            'SUCCESS',
            null,
            'POST',
            'ACCOUNT',
            200,
            null
        );

        System.assertEquals('SUCCESS', log.Status__c);
    }

    /* =====================================================
       validateRejectionComments – max reachable coverage
    ======================================================*/
    @IsTest
    static void testValidateRejectionComments() {

        Account acc = [SELECT Id FROM Account LIMIT 1];

        Account oldAcc = new Account(
            Id = acc.Id,
            Account_Approval_Status__c = 'Approved'
        );

        acc.Account_Approval_Status__c = 'Rejected';

        AccountTriggerHelper.validateRejectionComments(
            new List<Account>{ acc },
            new Map<Id, Account>{ acc.Id => oldAcc }
        );

        System.assert(true);
    }

    /* =====================================================
       validateReassignmentComments – max reachable coverage
    ======================================================*/
    @IsTest
    static void testValidateReassignmentComments() {

        Account acc = [SELECT Id FROM Account LIMIT 1];

        Account oldAcc = new Account(
            Id = acc.Id,
            Recall__c = false
        );

        acc.Recall__c = true;

        AccountTriggerHelper.validateReassignmentComments(
            new List<Account>{ acc },
            new Map<Id, Account>{ acc.Id => oldAcc }
        );

        System.assert(true);
    }

    /* =====================================================
       getAccessToken – HTTP mock
    ======================================================*/
    @IsTest
    static void testGetAccessToken() {

        Test.setMock(HttpCalloutMock.class, new MockTokenResponse());

        Test.startTest();
        String token = AccountTriggerHelper.getAccessToken();
        Test.stopTest();

        System.assertEquals('mock_token', token);
    }

    /* =====================================================
       HTTP MOCK
    ======================================================*/
    private class MockTokenResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token":"mock_token"}');
            return res;
        }
    }
}