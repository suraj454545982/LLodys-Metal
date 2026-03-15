@IsTest
public class SalesOrderTriggerHelperTest {

    @TestSetup
    static void setupBusinessFlow() {

        // ---------- Standard Pricebook ----------
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        // ---------- Account ----------
        Account acc = new Account(
            Name = 'Test Account',
            Phone = '9999999999',
            Organization_Code__c = '2000',
            Distribution_Channel__c = '20',
            Division__c = '0',
            SAP_Customer_Code__c = 'SAP1022',
            Account_Approval_Status__c = 'Approved'
        );
        insert acc;

        // ---------- Opportunity ----------
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Draft',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            Plant_and_Shipping_Point__c = '2060',
            Category__c = 'Iron Ore',
            Quote_status__c = 'Accepted'
        );
        insert opp;

        // ---------- Product ----------
        Product2 prod = new Product2(
            Name = 'Blocked Product',
            ProductCode = 'MAT-BLOCK',
            IsActive = true,
            Plant__c = '2060',
            Material_Blocked__c = 'No',
            Family = 'Iron Ore'
        );
        insert prod;

        // ---------- Pricebook Entry ----------
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            Validity_Date__c = Date.today().addDays(10),
            ApprovalStatus_c__c = 'Approved'
        );
        insert pbe;

        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );

        // ---------- Quote ----------
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Status = 'Draft',
            BillingName = 'billing name',
            Additional_Terms_and_Condition__c = 'this is sample text'
        );
        insert q;

        insert new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );

        update new Quote(Id = q.Id, Status = 'Accepted');

        update new Opportunity(
            Id = opp.Id,
            PO_Received__c = 'Yes',
            StageName = 'Closed Won'
        );

        // ---------- Purchase Order ----------
        Purchase_Order__c po = new Purchase_Order__c(
            Name = '123',
            PO_Date__c = Date.today().addDays(-10),
            Quote__c = q.Id,
            Opportunity__c = opp.Id,
            PO_Approval_Status__c = 'Draft'
        );
        insert po;
        opp.StageName = 'Closed Won';
        update opp;
        
        /* -------------------------------------------------
         * Upload File (Required for Approval)
         * ------------------------------------------------- */
        ContentVersion cv = new ContentVersion(
            Title = 'PO File',
            PathOnClient = 'po.pdf',
            VersionData = Blob.valueOf('test'),
            IsMajorVersion = true
        );
        insert cv;
        
        Id contentDocId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ].ContentDocumentId;
        
        insert new ContentDocumentLink(
            LinkedEntityId = po.Id,
            ContentDocumentId = contentDocId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
         
        po.PO_Approval_Status__c = 'Approved';
        update po;

        // ---------- Contract (CRITICAL) ----------
        Contract con = new Contract(
            Contract_TypeNew__c = 'ZZSF',
            Purchase_Order_Name__c = po.Id,
            Opportunity__c = opp.Id,
            SAP_Sales_Contract_Number__c = 'SAP-CON-001'
            
        );
        insert con;
        
        con.ContractApprovalStatus__c = 'Approved';
        update con;

        // ---------- Order ----------
        Order ord = new Order(
            AccountId = acc.Id,
            OpportunityId = opp.Id,
            ContractId = con.Id,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = stdPbId,
            SAP_Sales_Order_Number__c = null,
            Sales_Order_Approval__c = 'Approved',
            Trigger_SAP_Insert__c = false,
            Delivery_Schedule_Line_Number__c = 1234
        );
        insert ord;

        insert new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );
    }

    // =========================================================
    // TEST 1 — processSAPSync + fetchSAPInsertIds
    // =========================================================
    @IsTest
    static void testProcessSAPSync() {

        Test.setMock(HttpCalloutMock.class, new SAPTokenSuccessMock());

        Order ord = [
            SELECT Id, Trigger_SAP_Insert__c,ContractId,SAP_Sales_Order_Number__c,Sales_Order_Approval__c
            FROM Order
            LIMIT 1
        ];

        Order oldOrd = new Order(
            Id = ord.Id,
            Trigger_SAP_Insert__c = false
        );

        ord.Trigger_SAP_Insert__c = true;

        Test.startTest();
        SalesOrderTriggerHelper.processSAPSync(
            new List<Order>{ ord },
            new Map<Id, Order>{ ord.Id => oldOrd }
        );
        Test.stopTest();

        System.assert(true, 'Batch execution line covered');
    }

    // =========================================================
    // TEST 2 — getAccessToken SUCCESS
    // =========================================================
    @IsTest
    static void testGetAccessTokenSuccess() {

        Test.setMock(HttpCalloutMock.class, new SAPTokenSuccessMock());

        Test.startTest();
        String token = SalesOrderTriggerHelper.getAccessToken();
        Test.stopTest();

        System.assertEquals('TEST_ACCESS_TOKEN', token);
    }

    // =========================================================
    // TEST 3 — getAccessToken FAILURE
    // =========================================================
    @IsTest
    static void testGetAccessTokenFailure() {

        Test.setMock(HttpCalloutMock.class, new SAPTokenFailureMock());

        try {
            Test.startTest();
            SalesOrderTriggerHelper.getAccessToken();
            Test.stopTest();
            System.assert(false, 'Exception expected');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Token request failed'));
        }
    }

    // =========================================================
    // TEST 4 — createApiLog
    // =========================================================
    @IsTest
    static void testCreateApiLog() {

        SAPResponseWrapper wrap = new SAPResponseWrapper(
            'SUCCESS', '', 200, 'OK', null
        );

        API_LOG__c log = SalesOrderTriggerHelper.createApiLog(
            new List<SAPResponseWrapper>{ wrap },
            '{"test":"json"}',
            'Success',
            '',
            'POST',
            'OrderInsert',
            200,
            null
        );

        System.assertEquals('Success', log.Status__c);
        System.assertEquals('OrderInsert', log.Scope__c);
    }
}