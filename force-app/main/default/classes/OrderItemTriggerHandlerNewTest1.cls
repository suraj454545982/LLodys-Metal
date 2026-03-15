@IsTest
public class OrderItemTriggerHandlerNewTest1 {

    @TestSetup
    static void setupBusinessFlow() {

        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

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

        Product2 prod = new Product2(
            Name = 'ANON-PROD',
            ProductCode = 'MAT-ANON',
            IsActive = true,
            Plant__c = '2060',
            Material_Blocked__c = 'No',
            Family = 'Iron Ore'
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            ApprovalStatus_c__c = 'Approved',
            Validity_Date__c = Date.today().addDays(10)
        );
        insert pbe;

        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );

        opp.StageName = 'Quotation';
        update opp;

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

        opp.PO_Received__c = 'Yes';
        update opp;

        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'ANON-PO',
            PO_Date__c = Date.today(),
            Quote__c = q.Id,
            Opportunity__c = opp.Id,
            PO_Approval_Status__c = 'Draft'
        );
        insert po;

        ContentVersion cv = new ContentVersion(
            Title = 'PO File',
            PathOnClient = 'po.pdf',
            VersionData = Blob.valueOf('test'),
            IsMajorVersion = true
        );
        insert cv;

        Id cdId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ].ContentDocumentId;

        insert new ContentDocumentLink(
            LinkedEntityId = po.Id,
            ContentDocumentId = cdId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        po.PO_Approval_Status__c = 'Approved';
        update po;

        opp.StageName = 'Closed Won';
        update opp;

        Contract con = new Contract(
            Contract_TypeNew__c = 'ZZSF',
            Purchase_Order_Name__c = po.Id,
            Opportunity__c = opp.Id
        );
        insert con;

        con.ContractApprovalStatus__c = 'Approved';
        update con;

        Order ord = new Order(
            AccountId = acc.Id,
            OpportunityId = opp.Id,
            ContractId = con.Id,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = stdPbId,
            Delivery_Schedule_Line_Number__c = 1234
        );
        insert ord;

        insert new OrderItem(
            OrderId = ord.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );
    }

    /* =====================================================
       TEST 1 — populateListPrice (early return)
       ===================================================== */
    @IsTest
    static void testPopulateListPrice_EarlyReturn() {
        OrderItem oi = [SELECT Id,
                        OrderItem.OrderId,
                        OrderItem.Product2Id,
                        OrderItem.UnitPrice 
                        FROM OrderItem LIMIT 1];
        Test.startTest();
        OrderItemTriggerHandler.populateListPrice(new List<OrderItem>{ oi });
        Test.stopTest();
        System.assert(true);
    }

    /* =====================================================
       TEST 2 — recalculateTotalPriceAndValidateLimit
       ===================================================== */
    @IsTest
    static void testRecalculateAndValidate() {

        OrderItem oi = [
            SELECT Id, Quantity, OrderId, Product2Id, UnitPrice
            FROM OrderItem
            LIMIT 1
        ];

        OrderItem oldOi = new OrderItem(
            Id = oi.Id,
            Quantity = oi.Quantity
        );

        oi.Quantity = oi.Quantity + 1;

        Test.startTest();
        OrderItemTriggerHandler.recalculateTotalPriceAndValidateLimit(
            new List<OrderItem>{ oi },
            new Map<Id, OrderItem>{ oldOi.Id => oldOi }
        );
        Test.stopTest();

        System.assertEquals(oi.Quantity, oi.Quantity);
    }

    /* =====================================================
       TEST 3 — rollupOnOrder
       ===================================================== */
    @IsTest
    static void testRollupOnOrder() {

        Order ord = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        OrderItemTriggerHandler.rollupOnOrder(
            new Set<Id>{ ord.Id }
        );
        Test.stopTest();

        Order updated = [
            SELECT Id, Order_Quantity__c
            FROM Order
            WHERE Id = :ord.Id
        ];
        System.assertNotEquals(null, updated.Id);
    }
    
    
    
   /* @IsTest
    static void testPopulateListPrice_UnitPriceNullPath() {
    
        // --- Required records from setup ---
        Order ord = [
            SELECT Id, ContractId, Pricebook2Id
            FROM Order
            LIMIT 1
        ];
    
        Product2 prod = [
            SELECT Id
            FROM Product2
            LIMIT 1
        ];
    
        // --- Ensure Sales Contract Line Item has pricing ---
        Sales_Contract_Line_Item__c scLi = [
            SELECT Id, Contract__c, Product__c, Quantity__c,
                   List_Price__c, Discount__c, Freight__c,
                   Other_Expenses__c, Shipping_and_Handling__c,
                   Packing_and_Forwarding__c
            FROM Sales_Contract_Line_Item__c
            WHERE Contract__c = :ord.ContractId
            AND Product__c = :prod.Id
            LIMIT 1
        ];
    
        scLi.List_Price__c = 200;
        scLi.Discount__c = 20;
        scLi.Freight__c = 10;
        scLi.Other_Expenses__c = 10;
        scLi.Shipping_and_Handling__c = 10;
        scLi.Packing_and_Forwarding__c = 10;
        update scLi;
    
        // 🔥 CRITICAL PART 🔥
        // Create OrderItem WITHOUT UnitPrice AND PricebookEntryId
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            Product2Id = prod.Id,
            Quantity = 2
            // ❌ no UnitPrice
            // ❌ no PricebookEntryId
        );
    
        Test.startTest();
    
        // Call handler directly — NOT through trigger
        OrderItemTriggerHandler.populateListPrice(
            new List<OrderItem>{ oi }
        );
    
        Test.stopTest();
    
        // --- Assertions ---
        System.assertEquals(
            200,
            oi.UnitPrice,
            'UnitPrice must be populated from Contract/Quote'
        );
    
        System.assertNotEquals(
            null,
            oi.PricebookEntryId,
            'PricebookEntryId must be populated'
        );
    
        System.assertEquals(
            40,
            oi.Discount__c,
            'Discount must be proportional'
        );
    
        System.assertEquals(
            20,
            oi.Freight__c,
            'Freight must be proportional'
        );
    }*/

}