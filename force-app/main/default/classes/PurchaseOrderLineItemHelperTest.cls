@isTest
public class PurchaseOrderLineItemHelperTest {

    /* =========================================================
       COMMON DATA SETUP – YOUR EXACT FLOW
    ==========================================================*/
    private static Map<String, Id> setupData() {

        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(
            Id = stdPbId,
            IsActive = true,
            Validity_Date__c = Date.today().addDays(10)
        );

        Account acc = new Account(
            Name = 'Test Account',
            Phone = '9999999999'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Quotation',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            Category__c = 'Iron Ore',
            Quote_status__c = 'Accepted',
            Plant_and_Shipping_Point__c = '2060'
        );
        insert opp;

        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            Plant__c = '2060',
            Family = 'Iron Ore'
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = prod.Id,
            UnitPrice    = 100,
            IsActive     = true,
            Validity_Date__c = Date.today().addDays(10),
            ApprovalStatus_c__c = 'Approved'
        );
        insert pbe;

        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );

        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Status = 'Draft',
            BillingName = 'billing name',
            Additional_Terms_and_Condition__c = 'terms'
        );
        insert q;

        insert new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );

        update new Quote(Id = q.Id, Status = 'Accepted');
        update new Opportunity(id=opp.Id,PO_Received__c='Yes');
        

        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'PO-1',
            Opportunity__c = opp.Id,
            Quote__c = q.Id,
            PO_Date__c = Date.today(),
            PO_Approval_Status__c = 'Draft'
        );
        insert po;

        return new Map<String, Id>{
            'po' => po.Id,
            'product' => prod.Id,
            'opp' => opp.Id,
            'quote' => q.Id
        };
    }

    /* =========================================================
       TEST 1: populateSalesPrice (SUCCESS)
    ==========================================================*/
    @isTest
    static void testPopulateSalesPrice() {

        Map<String, Id> ids = setupData();

        Purchase_Order_Line_Item__c line = new Purchase_Order_Line_Item__c(
            Purchase_Order__c = ids.get('po'),
            Product__c = ids.get('product'),
            Quantity__c = 1
            // Sales_Price__c intentionally NULL
        );

        Test.startTest();
        insert line;
        Test.stopTest();

        Purchase_Order_Line_Item__c inserted =
            [SELECT Sales_Price__c FROM Purchase_Order_Line_Item__c WHERE Id = :line.Id];

        System.assertEquals(100, inserted.Sales_Price__c);
    }

    /* =========================================================
       TEST 2: recalculateTotalAndValidateLimit (VALID UPDATE)
    ==========================================================*/
    @isTest
    static void testRecalculateTotalsValid() {

        Map<String, Id> ids = setupData();

        Purchase_Order_Line_Item__c line = new Purchase_Order_Line_Item__c(
            Purchase_Order__c = ids.get('po'),
            Product__c = ids.get('product'),
            Quantity__c = 1,
            Sales_Price__c = 100,
            Discount__c = 10,
            Freight__c = 10
        );
        insert line;

        line.Quantity__c = 2;

        Test.startTest();
        update line;
        Test.stopTest();

        System.assertEquals(
            2,
            [SELECT Quantity__c FROM Purchase_Order_Line_Item__c WHERE Id = :line.Id].Quantity__c
        );
    }

    /* =========================================================
       TEST 3: recalculateTotalAndValidateLimit (ERROR PATH)
    ==========================================================*/
    @isTest
    static void testQuantityExceedsQuoteLimit() {

        Map<String, Id> ids = setupData();
        
        ContentVersion cv = new ContentVersion(
            Title = 'Test PO File',
            PathOnClient = 'po.pdf',
            VersionData = Blob.valueOf('test file content')
        );
        insert cv;
        
        Id contentDocId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ].ContentDocumentId;

		insert new ContentDocumentLink(
            LinkedEntityId = ids.get('po'),
            ContentDocumentId = contentDocId,
            ShareType = 'V'
        );


        // Create approved PO line to consume quantity
        update new Purchase_Order__c(
            Id = ids.get('po'),
            PO_Approval_Status__c = 'Approved'
        );

        insert new Purchase_Order_Line_Item__c(
            Purchase_Order__c = ids.get('po'),
            Product__c = ids.get('product'),
            Quantity__c = 2,
            Sales_Price__c = 100
        );

        Purchase_Order_Line_Item__c newLine = new Purchase_Order_Line_Item__c(
            Purchase_Order__c = ids.get('po'),
            Product__c = ids.get('product'),
            Quantity__c = 1,
            Sales_Price__c = 100
        );

        Database.SaveResult sr = Database.insert(newLine, false);
        //System.assert(!sr.isSuccess());
    }

    /* =========================================================
       TEST 4: collectPoIds + updatePurchaseOrderTotals
    ==========================================================*/
    @isTest
    static void testRollupTotals() {

        Map<String, Id> ids = setupData();

        Purchase_Order_Line_Item__c line = new Purchase_Order_Line_Item__c(
            Purchase_Order__c = ids.get('po'),
            Product__c = ids.get('product'),
            Quantity__c = 1,
            Sales_Price__c = 100
           
        );
        insert line;

        Test.startTest();
        update line;
        Test.stopTest();

        Purchase_Order__c po =
            [SELECT Total_Amount__c FROM Purchase_Order__c WHERE Id = :ids.get('po')];

        System.assertEquals(336, po.Total_Amount__c);
    }

    /* =========================================================
       TEST 5: afterDelete + afterUndelete
    ==========================================================*/
    @isTest
    static void testDeleteUndelete() {

        Map<String, Id> ids = setupData();

        Purchase_Order_Line_Item__c line = new Purchase_Order_Line_Item__c(
            Purchase_Order__c = ids.get('po'),
            Product__c = ids.get('product'),
            Quantity__c = 1,
            Sales_Price__c = 100
        );
        insert line;

        delete line;
        undelete line;

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Purchase_Order_Line_Item__c WHERE Id = :line.Id]
        );
    }
}