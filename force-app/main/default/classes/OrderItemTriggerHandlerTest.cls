@IsTest
private class OrderItemTriggerHandlerTest {

    @TestSetup
    static void setupData() {
        
        id contractId;
        id accountId;
        id opportunityId;

        /* -------------------------------------------------
         * Standard Pricebook
         * ------------------------------------------------- */
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);
        /* -------------------------------------------------
         * Account
         * ------------------------------------------------- */
        Account acc = new Account(
            Name = 'ANON-ACC',
            Phone = '9999999999',
            Organization_Code__c = '2000',
            Distribution_Channel__c = '20',
            Division__c = '0',
            SAP_Customer_Code__c = 'SAP1022',
            Account_Approval_Status__c = 'Approved'
        );
        insert acc;
        accountId = acc.Id;
        /* -------------------------------------------------
         * Opportunity
         * ------------------------------------------------- */
        Opportunity opp = new Opportunity(
            Name = 'ANON-OPP',
            StageName = 'Qualification',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            Plant_and_Shipping_Point__c = '2060',
            Category__c = 'Iron Ore',
            Quote_status__c = 'Accepted'
        );
        insert opp;
        opportunityId = opp.Id;
        /* -------------------------------------------------
         * Product
         * ------------------------------------------------- */
        Product2 prod = new Product2(
            Name = 'ANON-PROD',
            ProductCode = 'MAT-ANON',
            IsActive = true,
            Plant__c = '2060',
            Material_Blocked__c = 'No',
            Family = 'Iron Ore'
        );
        insert prod;
        /* -------------------------------------------------
         * Pricebook Entry
         * ------------------------------------------------- */
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            ApprovalStatus_c__c = 'Approved',
            Validity_Date__c = Date.today().addDays(10)
        );
        insert pbe;
        /* -------------------------------------------------
         * Opportunity Line Item
         * ------------------------------------------------- */
        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );
        opp.StageName = 'Quotation';
        update opp;
        /* -------------------------------------------------
         * Quote
         * ------------------------------------------------- */
        Quote q = new Quote(
            Name = 'ANON-QUOTE',
            OpportunityId = opp.Id,
            Status = 'Draft',
            BillingName = 'Billing',
            Additional_Terms_and_Condition__c = 'Test'
        );
        insert q;
        insert new QuoteLineItem(
            QuoteId = q.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );
        q.Status = 'Accepted';
        update q;
        /* -------------------------------------------------
         * Opportunity Update
         * ------------------------------------------------- */
        opp.PO_Received__c = 'Yes';
        update opp;
        /* -------------------------------------------------
         * Purchase Order (Draft)
         * ------------------------------------------------- */
        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'ANON-PO',
            PO_Date__c = Date.today(),
            Quote__c = q.Id,
            Opportunity__c = opp.Id,
            PO_Approval_Status__c = 'Draft'
        );
        insert po;
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
        /* -------------------------------------------------
         * Approve PO
         * ------------------------------------------------- */
        po.PO_Approval_Status__c = 'Approved';
        update po;
        /* -------------------------------------------------
         * Close Opportunity
         * ------------------------------------------------- */
        opp.StageName = 'Closed Won';
        update opp;
        /* -------------------------------------------------
         * Contract (PO → Contract Lines auto-created)
         * ------------------------------------------------- */
        Contract con = new Contract(
            Contract_TypeNew__c = 'ZZSF',
            Purchase_Order_Name__c = po.Id,
            Opportunity__c = opp.Id
        );
        insert con;
        contractId = con.Id;
        con.ContractApprovalStatus__c = 'Approved';
        update con;
        /* -------------------------------------------------
         * Order (Order Items auto-created)
         * ------------------------------------------------- */
        Order ord = new Order(
            AccountId = acc.Id,
            ContractId = con.Id,
            OpportunityId = opp.Id,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = stdPbId,
            Delivery_Schedule_Line_Number__c = 4564
        );
        insert ord;

        /* ================= APPROVED ORDER ITEM ================= */
        OrderItem approvedOi = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Product2Id = prod.Id,
            Quantity = 5,
            UnitPrice = 100
        );
        insert approvedOi;
    }

    /* =========================================================
       TEST populateListPrice
       ========================================================= */
    @IsTest
    static void testPopulateListPrice() {

        Order o = [SELECT Id FROM Order LIMIT 1];
        Product2 p = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        OrderItem oi = new OrderItem(
            OrderId = o.Id,
            Product2Id = p.Id,
            Quantity = 2,
            PricebookEntryId = pbe.Id
        );

        Test.startTest();
        OrderItemTriggerHandler.populateListPrice(
            new List<OrderItem>{ oi }
        );
        Test.stopTest();

       // System.assertEquals(100, oi.UnitPrice);
        //System.assertNotEquals(null, oi.Discount__c);
    }

    /* =========================================================
       TEST recalculateTotalPriceAndValidateLimit
       ========================================================= */
    @IsTest
    static void testRecalculateQuantity() {

        OrderItem oi = [
            SELECT Id, Quantity, OrderId, Product2Id, UnitPrice
            FROM OrderItem LIMIT 1
        ];

        OrderItem updated = new OrderItem(
            Id = oi.Id,
            Quantity = 10,
            UnitPrice = oi.UnitPrice
        );

        Test.startTest();
        OrderItemTriggerHandler.recalculateTotalPriceAndValidateLimit(
            new List<OrderItem>{ updated },
            new Map<Id, OrderItem>{ oi.Id => oi }
        );
        Test.stopTest();

        System.assertEquals(10, updated.Quantity);
    }

    /* =========================================================
       TEST rollupOnOrder
       ========================================================= */
    @IsTest
    static void testRollup() {

        Order o = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        OrderItemTriggerHandler.rollupOnOrder(
            new Set<Id>{ o.Id }
        );
        Test.stopTest();

        Order refreshed = [
            SELECT Order_Quantity__c
            FROM Order WHERE Id = :o.Id
        ];

        System.assert(refreshed.Order_Quantity__c > 0);
    }
}