@isTest
public class PurchaseOrderLineItemTriggerHandlerTest {

    /* =========================================================
       COMMON SETUP – SAME DATA YOU PROVIDED
    ==========================================================*/
    private static Map<String, Id> setupData() {

        // Standard Pricebook
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(
            Id = stdPbId,
            IsActive = true,
            Validity_Date__c = Date.today().addDays(10)
        );

        // Account
        Account acc = new Account(
            Name = 'Test Account',
            Phone = '9999999999'
        );
        insert acc;

        // Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Quotation',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            Category__c = 'Iron Ore',
            Quote_status__c = 'Accepted',
            Plant_and_Shipping_Point__c ='2060'
        );
        insert opp;

        // Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            Plant__c = '2060',
            Family = 'Iron Ore'
        );
        insert prod;

        // Pricebook Entry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = prod.Id,
            UnitPrice    = 100,
            IsActive     = true,
            Validity_Date__c = Date.today().addDays(10),
            ApprovalStatus_c__c = 'Approved'
        );
        insert pbe;

        // Opportunity Line Item
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

        // Quote Line Item
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );
        insert qli;

        // Accept Quote
        update new Quote(
            Id = q.Id,
            Status = 'Accepted'
        );

        // Update Opportunity
        update new Opportunity(
            Id = opp.Id,
            PO_Received__c = 'Yes'
        );

        // Purchase Order
        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'PO-123',
            Opportunity__c = opp.Id,
            Quote__c = q.Id,
            PO_Date__c = Date.today()
        );
        insert po;

        return new Map<String, Id>{
            'po' => po.Id,
            'product' => prod.Id
        };
    }

    /* =========================================================
       TEST: INSERT (beforeInsert + afterInsert)
    ==========================================================*/
    @isTest
    static void testInsertPOLineItem() {

        Map<String, Id> ids = setupData();

        Purchase_Order_Line_Item__c line = new Purchase_Order_Line_Item__c(
            Purchase_Order__c = ids.get('po'),
            Product__c = ids.get('product'),
            Quantity__c = 2,
            Sales_Price__c = 100
        );

        Test.startTest();
        insert line;
        Test.stopTest();

        System.assertNotEquals(null, line.Id);
    }

    /* =========================================================
       TEST: UPDATE (beforeUpdate + afterUpdate)
    ==========================================================*/
    @isTest
    static void testUpdatePOLineItem() {

        Map<String, Id> ids = setupData();

        Purchase_Order_Line_Item__c line = new Purchase_Order_Line_Item__c(
            Purchase_Order__c = ids.get('po'),
            Product__c = ids.get('product'),
            Quantity__c = 1,
            Sales_Price__c = 100
        );
        insert line;

        line.Quantity__c = 1;

        Test.startTest();
        update line;
        Test.stopTest();

        Purchase_Order_Line_Item__c updated =
            [SELECT Quantity__c FROM Purchase_Order_Line_Item__c WHERE Id = :line.Id];

        System.assertEquals(1, updated.Quantity__c);
    }

    /* =========================================================
       TEST: DELETE (afterDelete)
    ==========================================================*/
    @isTest
    static void testDeletePOLineItem() {

        Map<String, Id> ids = setupData();

        Purchase_Order_Line_Item__c line = new Purchase_Order_Line_Item__c(
            Purchase_Order__c = ids.get('po'),
            Product__c = ids.get('product'),
            Quantity__c = 1,
            Sales_Price__c = 100
        );
        insert line;

        Test.startTest();
        delete line;
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Purchase_Order_Line_Item__c WHERE Id = :line.Id]
        );
    }

    /* =========================================================
       TEST: UNDELETE (afterUndelete)
    ==========================================================*/
    @isTest
    static void testUndeletePOLineItem() {

        Map<String, Id> ids = setupData();

        Purchase_Order_Line_Item__c line = new Purchase_Order_Line_Item__c(
            Purchase_Order__c = ids.get('po'),
            Product__c = ids.get('product'),
            Quantity__c = 1,
            Sales_Price__c = 100
        );
        insert line;
        delete line;

        Test.startTest();
        undelete line;
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Purchase_Order_Line_Item__c WHERE Id = :line.Id]
        );
    }
}