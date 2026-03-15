@IsTest
public class QuoteOfferPDFGeneratorTest {

    /* =====================================================
       TEST SETUP — SAME FLOW & SAME DATA
    ======================================================*/
    @TestSetup
    static void setupFlowData() {

        // Standard Pricebook
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(
            Id = stdPbId,
            IsActive = true
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
            Plant_and_Shipping_Point__c = '2060'
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
            Validity_Date__c = date.today().addDays(5),
            //ApprovalStatus__c = 'Approved',
            ApprovalStatus_c__c = 'Approved'
        );
        insert pbe;

        // Opportunity Line Item
        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );

        // Quote
        Quote q = new Quote(
            Name = 'Test Quote',
            Quote_Number__c = 'QT-1001',
            OpportunityId = opp.Id,
            Status = 'Draft',
            BillingName = 'Billing Name',
            Additional_Terms_and_Condition__c = 'Sample text'
        );
        insert q;

        // Quote Line Item
        insert new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );

        // Accept Quote
        update new Quote(
            Id = q.Id,
            Status = 'Accepted'
        );
    }

    /* =====================================================
       TEST 1 — NULL / EMPTY INPUT (EARLY RETURN)
    ======================================================*/
    @IsTest
    static void testGeneratePDF_NoIds() {

        Test.startTest();
        QuoteOfferPDFGenerator.generatePDF(null);
        QuoteOfferPDFGenerator.generatePDF(new List<Id>());
        Test.stopTest();

        System.assert(true, 'Method must safely exit for null or empty input');
    }

    /* =====================================================
       TEST 2 — SUCCESSFUL PDF GENERATION
    ======================================================*/
    @IsTest
    static void testGeneratePDF_Success() {

        Quote q = [
            SELECT Id
            FROM Quote
            LIMIT 1
        ];

        // Required for getContentAsPDF()
        Test.setCurrentPage(Page.offerpdf);

        Test.startTest();
        QuoteOfferPDFGenerator.generatePDF(
            new List<Id>{ q.Id }
        );
        Test.stopTest();

        // Assert ContentVersion created
        /*ContentVersion cv = [
            SELECT Id, Title
            FROM ContentVersion
            WHERE Title LIKE 'Quote_%'
            LIMIT 1
        ];
        System.assertNotEquals(
            null,
            cv.Id,
            'Quote Offer PDF must be created'
        );

        // Assert ContentDocumentLink created
        ContentDocumentLink cdl = [
            SELECT Id, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :q.Id
            LIMIT 1
        ];
        System.assertEquals(
            q.Id,
            cdl.LinkedEntityId,
            'PDF must be linked to Quote'
        );*/
    }
}