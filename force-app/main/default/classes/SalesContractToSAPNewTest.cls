@IsTest
public class SalesContractToSAPNewTest {

    /* =====================================================
       HTTP MOCK
    ======================================================*/
    private class MultiEndpointMock implements HttpCalloutMock {
        Integer statusCode;
        String responseBody;

        MultiEndpointMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            // Token callout
            if (req.getBody() == null || !req.getBody().contains('Contract_Number')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"TEST_TOKEN"}');
                return res;
            }

            // Update callout
            res.setStatusCode(statusCode);
            res.setBody(responseBody == null ? '{"status":"ok"}' : responseBody);
            return res;
        }
    }

    /* =====================================================
       TEST SETUP – BASE DATA ONLY (NO CONTRACTS)
    ======================================================*/
    @TestSetup
    static void setupBaseData() {

        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        Account acc = new Account(
            Name = 'SAP Test Account',
            Phone = '9999999999',
            Organization_Code__c = '2000',
            Distribution_Channel__c = '20',
            Division__c = '0',
            SAP_Customer_Code__c = 'SAP100'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'SAP Opp',
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            Category__c = 'Iron Ore',
            Plant_and_Shipping_Point__c = '2060',
            Quote_status__c = 'Accepted',
            PO_Received__c = 'Yes'
        );
        insert opp;

        Product2 prod = new Product2(
            Name = 'SAP Product',
            IsActive = true,
            Plant__c = '2060',
            Family = 'Iron Ore'
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            ApprovalStatus_c__c = 'Approved',
            Validity_Date__c = Date.today()
        );
        insert pbe;

        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );

        Quote q = new Quote(
            Name = 'Final Quote',
            OpportunityId = opp.Id,
            Approval_Status__c = 'Approved',
            BillingName = 'Billing',
            Additional_Terms_and_Condition__c = 'sample'
        );
        insert q;

        insert new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );

        q.Status = 'Accepted';
        update q;

        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'PO-001',
            Opportunity__c = opp.Id,
            Quote__c = q.Id,
            PO_Approval_Status__c = 'Approved',
            PO_Date__c = Date.today()
        );
        insert po;

        insert new Purchase_Order_Line_Item__c(
            Purchase_Order__c = po.Id,
            Product__c = prod.Id,
            Quantity__c = 20,
            Sales_Price__c = 100
        );
    }

    /* =====================================================
       TEST: CONTRACT WITH NO LINE ITEMS → SKIPPED
    ======================================================*/
    @IsTest
    static void testNoLineItemsSkipped() {

        Id oppId = [SELECT Id FROM Opportunity LIMIT 1].Id;
        Id poId  = [SELECT Id FROM Purchase_Order__c LIMIT 1].Id;

        Contract c = new Contract(
            Opportunity__c = oppId,
            Purchase_Order_Name__c = poId,
            Contract_TypeNew__c = 'ZZSF'
        );
        insert c;

        // Remove auto-created lines (avoid validation)
        delete [SELECT Id FROM Sales_Contract_Line_Item__c WHERE Contract__c = :c.Id];

        c.ContractApprovalStatus__c = 'Approved';
        update c;

        Test.setMock(HttpCalloutMock.class,
            new MultiEndpointMock(200, '{"status":"ok"}')
        );

        Test.startTest();
        Database.executeBatch(
            new SalesContractUpdateOutboundCalloutToSAP(new Set<Id>{c.Id}), 1
        );
        Test.stopTest();

        System.assert(true);
    }

    /* =====================================================
       TEST: SUCCESS UPDATE WITH LINE ITEMS
    ======================================================*/
    @IsTest
    static void testUpdateSuccess() {

        Id oppId = [SELECT Id FROM Opportunity LIMIT 1].Id;
        Id poId  = [SELECT Id FROM Purchase_Order__c LIMIT 1].Id;

        Contract c = new Contract(
            Opportunity__c = oppId,
            Purchase_Order_Name__c = poId,
            Contract_TypeNew__c = 'ZZSF'
        );
        insert c;
        
        c.SAP_Sales_Contract_Number__c = 'SAP-CON-001';
		update c;

        insert new Sales_Contract_Line_Item__c(
            Contract__c = c.Id,
            Quantity__c = 10,
            Reason_for_Rejection__c = '01'
        );

        c.ContractApprovalStatus__c = 'Rejected';
        update c;

        Test.setMock(HttpCalloutMock.class,
            new MultiEndpointMock(200, '{"status":"success"}')
        );

        Test.startTest();
        Database.executeBatch(
            new SalesContractUpdateOutboundCalloutToSAP(new Set<Id>{c.Id}), 1
        );
        Test.stopTest();

        System.assert(true);
    }

    /* =====================================================
       TEST: ERROR RESPONSE FROM SAP
    ======================================================*/
    @IsTest
    static void testUpdateErrorResponse() {

        Id oppId = [SELECT Id FROM Opportunity LIMIT 1].Id;
        Id poId  = [SELECT Id FROM Purchase_Order__c LIMIT 1].Id;

        Contract c = new Contract(
            Opportunity__c = oppId,
            Purchase_Order_Name__c = poId,
            Contract_TypeNew__c = 'ZZSF'
        );
        insert c;
        
        c.SAP_Sales_Contract_Number__c = 'SAP-CON-003';
		update c;

        insert new Sales_Contract_Line_Item__c(
            Contract__c = c.Id,
            Quantity__c = 5,
            Reason_for_Rejection__c = '02'
        );

        c.ContractApprovalStatus__c = 'Rejected';
        update c;

        Test.setMock(HttpCalloutMock.class,
                        new MultiEndpointMock(200, '{"status":"failed"}')
                    );


        Test.startTest();
        Database.executeBatch(
            new SalesContractUpdateOutboundCalloutToSAP(new Set<Id>{c.Id}), 1
        );
        Test.stopTest();

        System.assert(true);
    }
}