@isTest
public class PurchaseOrderHelperNewTest {

    /* ===============================
       COMMON DATA FACTORY (SAFE)
       =============================== */
    private static Map<String, Id> setupData() {

        Id pbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = pbId, IsActive = true);

        Account acc = new Account(
            Name = 'TestAcc',
            Phone = '9999999999',
            Organization_Code__c = '2000',
            Distribution_Channel__c = '20',
            Division__c = '0'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'TestOpp',
            StageName = 'Quotation',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            PO_Received__c = 'Yes',
            Plant_and_Shipping_Point__c = '2060',
            Category__c = 'Iron Ore'
        );
        insert opp;

        Product2 prod = new Product2(
            Name = 'TestProd',
            IsActive = true,
            Family = 'Iron Ore',
            Plant__c = '2060'
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            ApprovalStatus_c__c = 'Approved',
            Validity_Date__c = Date.today().addDays(10)
        );
        insert pbe;

        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 10,
            UnitPrice = 100
        );

        // 🔴 IMPORTANT: Quote stays Draft in setup
        Quote q = new Quote(
            Name = 'TestQuote',
            OpportunityId = opp.Id,
            Status = 'Draft',
            BillingName = 'Test',
            Pricebook2Id = pbId,
            Additional_Terms_and_Condition__c = 'this is sample text'
        );
        insert q;

        insert new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 10,
            UnitPrice = 100,
            Discount__c = 10,
            Freight__c = 5,
            Shipping_and_Handling__c = 3,
            Packing_and_Forwarding__c = 2,
            Other_Expenses__c = 1
        );

        return new Map<String, Id>{
            'opp' => opp.Id,
            'quote' => q.Id,
            'product' => prod.Id,
            'pbe' => pbe.Id
        };
    }

    /* ===============================
       SUCCESS CASE
       =============================== */
    @isTest
    static void testMapQuoteToPO_Success() {
        Map<String, Id> ids = setupData();

        // Accept quote ONLY here
        update new Quote(Id = ids.get('quote'), Status = 'Accepted');

        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'PO1',
            Opportunity__c = ids.get('opp'),
            Quote__c = ids.get('quote'),
            PO_Date__c = Date.today()
        );

        Test.startTest();
        insert po;
        Test.stopTest();

        List<Purchase_Order_Line_Item__c> lines =
            [SELECT Quantity__c, Discount__c FROM Purchase_Order_Line_Item__c WHERE Purchase_Order__c = :po.Id];

        System.assertEquals(1, lines.size());
        System.assertEquals(10, lines[0].Quantity__c);
    }

    /* ===============================
       DRAFT PO BLOCK
       =============================== */
    @isTest
    static void testMapQuoteToPO_DraftPOBlocks() {
        Map<String, Id> ids = setupData();
        update new Quote(Id = ids.get('quote'), Status = 'Accepted');

        insert new Purchase_Order__c(
            Name = 'DraftPO',
            Opportunity__c = ids.get('opp'),
            Quote__c = ids.get('quote'),
            PO_Approval_Status__c = 'Draft',
            PO_Date__c = Date.today()
        );

        Purchase_Order__c newPo = new Purchase_Order__c(
            Name = 'NewPO',
            Opportunity__c = ids.get('opp'),
            Quote__c = ids.get('quote'),
            PO_Date__c = Date.today()
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(newPo, false);
        Test.stopTest();

        System.assert(!sr.isSuccess());
    }

    /* ===============================
       FILE VALIDATION (WITH FILE)
       =============================== */
    @isTest
    static void testFileValidation_WithFile() {
        Map<String, Id> ids = setupData();
        update new Quote(Id = ids.get('quote'), Status = 'Accepted');

        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'PO',
            Opportunity__c = ids.get('opp'),
            Quote__c = ids.get('quote'),
            PO_Date__c = Date.today(),
            PO_Approval_Status__c = 'Draft'
        );
        insert po;

        ContentVersion cv = new ContentVersion(
            Title = 'File',
            PathOnClient = 'file.pdf',
            VersionData = Blob.valueOf('data')
        );
        insert cv;

        Id docId = [
            SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id
        ].ContentDocumentId;

        insert new ContentDocumentLink(
            LinkedEntityId = po.Id,
            ContentDocumentId = docId,
            ShareType = 'V'
        );

        Test.startTest();
        update new Purchase_Order__c(Id = po.Id, PO_Approval_Status__c = 'Approved');
        Test.stopTest();

        System.assertEquals(
            'Approved',
            [SELECT PO_Approval_Status__c FROM Purchase_Order__c WHERE Id = :po.Id].PO_Approval_Status__c
        );
    }
}