@IsTest
public class ProformaInvoiceHandlerTest {

    /* =========================================================
       FULL DATA SETUP – EXACT FLOW YOU PROVIDED
    ==========================================================*/
    private static Map<String, Id> setupSampleFlow() {

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
            Status = 'Accepted',
            OpportunityId = opp.Id
        );

        // Update Opportunity
        update new Opportunity(
            Id = opp.Id,
            PO_Received__c = 'Yes'
        );

        // Purchase Order
        Purchase_Order__c po = new Purchase_Order__c(
            Name = '123',
            PO_Date__c = Date.today().addDays(-10),
            Quote__c = q.Id,
            Opportunity__c = opp.Id,
            PO_Approval_Status__c = 'Approved'
        );
        insert po;

        return new Map<String, Id>{
            'opp' => opp.Id,
            'po'  => po.Id
        };
    }

    /* =========================================================
       TEST 1: BEFORE INSERT – NUMBER ASSIGNMENT
    ==========================================================*/
    @IsTest
    static void testBeforeInsert_AssignsNumber() {

        Map<String, Id> ids = setupSampleFlow();

        Proforma_invoice__c pi = new Proforma_invoice__c(
            Opportunity__c = ids.get('opp'),
            Purchase_Order__c = ids.get('po')
        );

        Test.startTest();
        ProformaInvoiceHandler.handleBeforeInsert(
            new List<Proforma_invoice__c>{ pi }
        );
        Test.stopTest();

        System.assertNotEquals(
            null,
            pi.Proforma_Invoice_Number__c,
            'Proforma Invoice number should be assigned'
        );

        System.assertEquals(
            10,
            pi.Proforma_Invoice_Number__c.length(),
            'Invoice number must be 10 digits'
        );
    }

    /* =========================================================
       TEST 2: SEQUENTIAL NUMBERING
    ==========================================================*/
    @IsTest
    static void testSequentialInvoiceNumbers() {

        Map<String, Id> ids = setupSampleFlow();

        Proforma_invoice__c pi1 = new Proforma_invoice__c(
            Opportunity__c = ids.get('opp'),
            Purchase_Order__c = ids.get('po')
        );

        Proforma_invoice__c pi2 = new Proforma_invoice__c(
            Opportunity__c = ids.get('opp'),
            Purchase_Order__c = ids.get('po')
        );

        Test.startTest();
        ProformaInvoiceHandler.handleBeforeInsert(
            new List<Proforma_invoice__c>{ pi1, pi2 }
        );
        Test.stopTest();

        Long n1 = Long.valueOf(pi1.Proforma_Invoice_Number__c);
        Long n2 = Long.valueOf(pi2.Proforma_Invoice_Number__c);

        System.assertEquals(
            n1 + 1,
            n2,
            'Invoice numbers must be sequential'
        );
    }

    /* =========================================================
       TEST 3: PREVENT MANUAL UPDATE
    ==========================================================*/
    @IsTest
    static void testPreventManualUpdate() {

        Map<String, Id> ids = setupSampleFlow();

        Proforma_invoice__c pi = new Proforma_invoice__c(
            Opportunity__c = ids.get('opp'),
            Purchase_Order__c = ids.get('po')
        );
        insert pi;

        Proforma_invoice__c oldPi = pi.clone(false, true, true, true);

        pi.Proforma_Invoice_Number__c = '9999999999';

        Test.startTest();
        ProformaInvoiceHandler.handleBeforeUpdate(
            new List<Proforma_invoice__c>{ pi },
            new Map<Id, Proforma_invoice__c>{ pi.Id => oldPi }
        );
        Test.stopTest();

        System.assert(
            pi.getErrors().size() > 0,
            'Manual modification should throw error'
        );
    }

    /* =========================================================
       TEST 4: NULL / EMPTY SAFETY
    ==========================================================*/
    @IsTest
    static void testNullAndEmptySafety() {

        Test.startTest();
        ProformaInvoiceHandler.handleBeforeInsert(null);
        ProformaInvoiceHandler.handleBeforeInsert(new List<Proforma_invoice__c>());
        Test.stopTest();

        System.assert(true);
    }
}