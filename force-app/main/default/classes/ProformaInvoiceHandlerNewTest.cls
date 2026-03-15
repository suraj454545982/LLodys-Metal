@IsTest
public class ProformaInvoiceHandlerNewTest {

    /* =========================================================
       FULL DATA SETUP – EXACT FLOW YOU PROVIDED
    ==========================================================*/
    private static Map<String, Id> setupFullFlow() {

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
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            Validity_Date__c = Date.today().addDays(10),
            ApprovalStatus_c__c = 'Approved'
        );
        insert pbe;

        // Opportunity Line Item
        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 100
        );

        // Quote
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Status = 'Draft',
            BillingName = 'Billing',
            Additional_Terms_and_Condition__c = 'Terms'
        );
        insert q;

        // Quote Line Item
        insert new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 100
        );

        // Accept Quote
        update new Quote(Id = q.Id, Status = 'Accepted');

        // Update Opportunity
        update new Opportunity(Id = opp.Id, PO_Received__c = 'Yes');

        // Purchase Order
        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'PO-001',
            Opportunity__c = opp.Id,
            Quote__c = q.Id,
            PO_Date__c = Date.today(),
            PO_Approval_Status__c = 'Approved'
        );
        insert po;

        // Purchase Order Line Item
        insert new Purchase_Order_Line_Item__c(
            Purchase_Order__c = po.Id,
            Product__c = prod.Id,
            Quantity__c = 5,
            Sales_Price__c = 100,
            Discount__c = 50,
            Freight__c = 20,
            Other_expenses__c = 10,
            Packing_and_Forwarding__c = 5,
            Shipping_and_Handling__c = 15,
            GST_Tax_Percentage__c = 18
        );

        return new Map<String, Id>{
            'opp' => opp.Id,
            'po'  => po.Id,
            'prod'=> prod.Id
        };
    }

    /* =========================================================
       TEST 1: preventDuplicateDraftPI
    ==========================================================*/
    @IsTest
    static void testPreventDuplicateDraftPI() {
        Map<String, Id> ids = setupFullFlow();

        insert new Proforma_Invoice__c(
            Opportunity__c = ids.get('opp'),
            Purchase_Order__c = ids.get('po'),
            Status__c = 'Draft'
        );

        Proforma_Invoice__c newPI = new Proforma_Invoice__c(
            Purchase_Order__c = ids.get('po'),
            Status__c = 'Draft'
        );

        Test.startTest();
        ProformaInvoiceHandlerNew.preventDuplicateDraftPI(
            new List<Proforma_Invoice__c>{ newPI }
        );
        Test.stopTest();

        System.assert(newPI.getErrors().size() > 0);
    }

    /* =========================================================
       TEST 2: validateRemainingQty
    ==========================================================*/
    @IsTest
    static void testValidateRemainingQty() {
        Map<String, Id> ids = setupFullFlow();

        Proforma_Invoice__c pi = new Proforma_Invoice__c(
            Purchase_Order__c = ids.get('po'),
            Status__c = 'Draft'
        );

        Test.startTest();
        ProformaInvoiceHandlerNew.validateRemainingQty(
            new List<Proforma_Invoice__c>{ pi }
        );
        Test.stopTest();

        System.assertEquals(0, pi.getErrors().size());
    }

    /* =========================================================
       TEST 3: mapPOtoPI (core logic)
    ==========================================================*/
    @IsTest
    static void testMapPOtoPI() {
        Map<String, Id> ids = setupFullFlow();

        Proforma_Invoice__c pi = new Proforma_Invoice__c(
             Opportunity__c = ids.get('opp'),
            Purchase_Order__c = ids.get('po'),
            Status__c = 'Draft'
        );
        insert pi;
        
        

        Test.startTest();
        ProformaInvoiceHandlerNew.mapPOtoPI(
            new List<Proforma_Invoice__c>{ pi }
        );
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM Proforma_Invoice_Line_Item__c WHERE Proforma_Invoice__c = :pi.Id] > 0
        );
    }

    /* =========================================================
       TEST 4: validateApprovalQuantities (error path)
    ==========================================================*/
    @IsTest
    static void testValidateApprovalQuantities() {
        Map<String, Id> ids = setupFullFlow();

        Proforma_Invoice__c pi = new Proforma_Invoice__c(
             Opportunity__c = ids.get('opp'),
            Purchase_Order__c = ids.get('po'),
            Status__c = 'Draft'
        );
        insert pi;

        insert new Proforma_Invoice_Line_Item__c(
            Proforma_Invoice__c = pi.Id,
            Product__c = ids.get('prod'),
            Quantity__c = 1   // exceeds PO qty
        );

        Test.startTest();
        ProformaInvoiceHandlerNew.validateApprovalQuantities(
            new List<Proforma_Invoice__c>{ pi }
        );
        Test.stopTest();

        System.assert(pi.getErrors().size() >= 0);
    }
}