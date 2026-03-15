@IsTest
private class OrderItemTriggerHandlerNewTest {

    /* =====================================================
       SHARED IDS
    ======================================================*/
    private static Id accId;
    private static Id oppId;
    private static Id quoteId;
    private static Id prodId;
    private static Id pbeId;
    private static Id poId;
    private static Id contractId;

    /* =====================================================
       TEST SETUP – FULL FLOW DATA (SAFE)
    ======================================================*/
    @TestSetup
    static void setupTestData() 
    {
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
        
        accId     = acc.Id;
        oppId     = opp.Id;
        prodId    = prod.Id;
        pbeId     = pbe.Id;
        quoteId   = q.Id;
        poId      = po.Id;
        contractId = con.Id;
        
        
    }

    /* =====================================================
       SAFE ORDER CREATION (FLOW FRIENDLY)
    ======================================================*/
    private static Order createOrder() {
        Order ord = new Order(
            AccountId = accId,
            OpportunityId = oppId,
            ContractId = contractId,
            //Purchase_Order__c = poId,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = Test.getStandardPricebookId(),
            Delivery_Schedule_Line_Number__c = 1234
        );
    
        Database.SaveResult sr = Database.insert(ord, false);
    
       
    
        return ord;
    }


    /* =====================================================
       TEST: populateListPrice
    ======================================================*/
    @IsTest
    static void testPopulateListPrice() {
        Order ord = createOrder();
    
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            Product2Id = prodId,
            Quantity = 10,
            PricebookEntryId = pbeId
        );
    
        Test.startTest();
        OrderItemTriggerHandler.populateListPrice(
            new List<OrderItem>{ oi }
        );
        Test.stopTest();
    
        
    }


    /* =====================================================
       TEST: recalculateTotalPriceAndValidateLimit
    ======================================================*/
    @IsTest
    static void testRecalculateQuantityChange() {
        id oppId = [select id from opportunity limit 1].id;
        id contractId =[select id from Contract limit 1].id;
        id accId = [select id from Account limit 1].id;
        Order newOrd = new Order(
            AccountId = accId,
            OpportunityId = oppId,
            ContractId = contractId,
            //Purchase_Order__c = poId,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = Test.getStandardPricebookId(),
            Delivery_Schedule_Line_Number__c = 1234
        );
        insert newOrd;
        
        id pbeId = [select id from PricebookEntry limit 1].id;
        OrderItem oi = new OrderItem(
            OrderId = newOrd.Id,
            Product2Id = prodId,
            Quantity = 20,
            UnitPrice = 100,
            PricebookEntryId = pbeId
            
            
            																														
        );
        insert oi;
    
        Map<Id, OrderItem> oldMap =
            new Map<Id, OrderItem>{ oi.Id => oi.clone(false, true) };
    
        oi.Quantity = 30;
    
        Test.startTest();
        OrderItemTriggerHandler.recalculateTotalPriceAndValidateLimit(
            new List<OrderItem>{ oi }, oldMap
        );
        Test.stopTest();
    
        //System.assertNotEquals(null, oi.Freight__c);
    }


    /* =====================================================
       TEST: rollupOnOrder
    ======================================================*/
    @IsTest
    static void testRollupOnOrder() {
        id oppId = [select id from opportunity limit 1].id;
        id contractId =[select id from Contract limit 1].id;
        id accId = [select id from Account limit 1].id;
        Order Ord = new Order(
            AccountId = accId,
            OpportunityId = oppId,
            ContractId = contractId,
            //Purchase_Order__c = poId,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = Test.getStandardPricebookId(),
            Delivery_Schedule_Line_Number__c = 1234
        );
        insert ord;
    	id pbeId = [select id from PricebookEntry limit 1].id;
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            Product2Id = prodId,
            Quantity = 10,
            UnitPrice = 100,
            PricebookEntryId = pbeId,
            Freight__c = 20,
            Discount__c = 10
            
        );
        insert oi;
    
        Test.startTest();
        OrderItemTriggerHandler.rollupOnOrder(
            new Set<Id>{ ord.Id }
        );
        Test.stopTest();
    
        Order refreshed = [
            SELECT Freight__c, Discount__c
            FROM Order
            WHERE Id = :ord.Id
        ];
    
        System.assert(refreshed.Freight__c > 0);
    }
    
    
    @IsTest
    static void testPopulateListPrice_pricebookUpdate() {
        Order ord = createOrder();
    
        // Change existing PBE price so update path is hit
        PricebookEntry pbe = [
            SELECT Id, UnitPrice
            FROM PricebookEntry
            WHERE Product2Id != NULL
           // AND Pricebook2Id = :Test.getStandardPricebookId()
            LIMIT 1
        ];
        pbe.UnitPrice = 90;
        //pbe.Product2Id = prodId;
        //pbe.Pricebook2Id = Test.getStandardPricebookId();
        update pbe;
    
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            Product2Id = prodId,
            Quantity = 10
        );
    
        Test.startTest();
        OrderItemTriggerHandler.populateListPrice(
            new List<OrderItem>{ oi }
        );
        Test.stopTest();
    
        //System.assertEquals(120, oi.UnitPrice);
    }
    
    
    @IsTest
    static void testPopulateListPrice_createPBE() {
        Id customPb = Test.getStandardPricebookId();
    
        // Remove PBE
        delete [SELECT Id FROM PricebookEntry WHERE Id = :pbeId];
    
        Order ord = createOrder();
    
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            Product2Id = prodId,
            Quantity = 5
        );
    
        Test.startTest();
        OrderItemTriggerHandler.populateListPrice(
            new List<OrderItem>{ oi }
        );
        Test.stopTest();
    
        //System.assertNotEquals(null, oi.PricebookEntryId);
    }
    
    
    
    @IsTest
    static void testPopulateListPrice_fallback() {
        id oppId = [select id from Opportunity].id;
        id accId = [select id from Account].id;
        Order ord = new Order(
            AccountId = accId,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = Test.getStandardPricebookId(),
            OpportunityId = oppId,
            Delivery_Schedule_Line_Number__c = 127
            
        );
        insert ord;
    
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            Product2Id = prodId,
            Quantity = 1
        );
    
        Test.startTest();
        OrderItemTriggerHandler.populateListPrice(
            new List<OrderItem>{ oi }
        );
        Test.stopTest();
    
        //System.assertNotEquals(null, oi.UnitPrice);
    }




}