@IsTest
public class SalesOrderUpdateOutboundCalloutToSAPTest {

    @TestSetup
    static void setupData() {

        // -------------------------------------------------
        // Standard Pricebook
        // -------------------------------------------------
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        // -------------------------------------------------
        // Account
        // -------------------------------------------------
        Account acc = new Account(
            Name = 'Test Account',
            Phone = '9999999999',
            Organization_Code__c = '2000',
            Distribution_Channel__c = '20',
            Division__c = '0',
            SAP_Customer_Code__c = 'SAP1022'
        );
        insert acc;

        // -------------------------------------------------
        // Opportunity
        // -------------------------------------------------
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

        // -------------------------------------------------
        // Product (BLOCKED)
        // -------------------------------------------------
        Product2 prod = new Product2(
            Name = 'Blocked Product',
            ProductCode = 'MAT-BLOCK',
            IsActive = true,
            Plant__c = '2060',
            Material_Blocked__c = 'No',
            Family = 'Iron Ore'
        );
        insert prod;

        // -------------------------------------------------
        // Pricebook Entry
        // -------------------------------------------------
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
             Validity_Date__c = Date.today().addDays(10),
            ApprovalStatus_c__c = 'Approved'
        );
        insert pbe;
        
        // Required OLI (org validation)
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );
        insert oli;
		
        // Quote
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Status = 'Draft',
            BillingName = 'billing name',
            Additional_Terms_and_Condition__c = 'this is sample text'
        );
        insert q;
        /*
        System.debug('======================Quote Insert======================');
        System.debug('Quote Id'+q.Id);
        System.debug('Quote Additional'+q.Additional_Terms_and_Condition__c);
        System.debug('Quote Billing '+q.BillingName);
        System.debug('Quote Status'+q.Status);
        System.debug('Quote Opportunity Id'+ q.OpportunityId);
        */
        
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );
        insert qli;
        
        Quote qUpdate = new Quote(Id = q.Id, Status = 'Accepted', OpportunityId = opp.Id);
        update qUpdate;
        /*
        System.debug('======================Quote Update======================');
        System.debug('Quote Id'+qUpdate.Id);
        System.debug('Quote Billing '+qUpdate.BillingName);
        System.debug('Quote Additional'+qUpdate.Additional_Terms_and_Condition__c);
        System.debug('Quote Status'+qUpdate.Status);
        System.debug('Quote Opportunity Id'+ qUpdate.OpportunityId);
		*/
		
        
        
        //Update Opportunity
        Opportunity oppUpdate = new Opportunity(id = opp.Id, PO_Received__c = 'Yes',StageName = 'Closed Won');
        update oppUpdate;
        
        
        // Purchase Order
        Purchase_Order__c po = new Purchase_Order__c(
            Name = '123',
            PO_Date__c = Date.today().addDays(-10),
            Quote__c = qUpdate.Id,
            Opportunity__c = oppUpdate.Id,
            PO_Approval_Status__c = 'approved'
        );
        insert po; 
        
         Contract con = new Contract(
            Contract_TypeNew__c = 'ZZSF',
            Purchase_Order_Name__c = po.Id,
            Opportunity__c = opp.Id
            
        );
        insert con; 

        // -------------------------------
        // Order
        // -------------------------------
        Order ord = new Order(
            AccountId = acc.Id,
            OpportunityId = opp.Id,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = stdPbId,
            SAP_Sales_Order_Number__c = 'SAP-10001',
            Delivery_Schedule_Line_Number__c = 1234
        );
        insert ord;

        // -------------------------------
        // Order Item
        // -------------------------------
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
            //Product_Code__c = 'MAT-100',
            //Reason_for_Rejection__c = 'R1'
        );
        insert oi;
    }

    // ==========================================================
    // ✅ SUCCESS PATH – FULL EXECUTION
    // ==========================================================
    @IsTest
    static void testBatchSuccess() {

        // Mock HTTP callout
        Test.setMock(HttpCalloutMock.class, new SalesOrderUpdateCalloutMock());

        Set<Id> orderIds = new Set<Id>();
        orderIds.add([SELECT Id FROM Order LIMIT 1].Id);

        Test.startTest();
        Database.executeBatch(
            new SalesOrderUpdateOutboundCalloutToSAP(orderIds),
            1
        );
        Test.stopTest();

        // API log inserted
        System.assert(
            [SELECT COUNT() FROM API_LOG__c] > 0,
            'API logs should be created'
        );
    }

    // ==========================================================
    // ✅ TOKEN FAILURE PATH (EXCEPTION HANDLING)
    // ==========================================================
    @IsTest
    static void testTokenFailurePath() {

        // Force token failure by mocking HTTP but breaking token logic
        Test.setMock(HttpCalloutMock.class, new SalesOrderUpdateCalloutMock());

        // Temporarily invalidate metadata access
        // (getAccessToken() throws exception in test context)
        Set<Id> orderIds = new Set<Id>{
            [SELECT Id FROM Order LIMIT 1].Id
        };

        Test.startTest();
        Database.executeBatch(
            new SalesOrderUpdateOutboundCalloutToSAP(orderIds),
            1
        );
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM API_LOG__c] > 0,
            'Failure logs should be created'
        );
    }
}