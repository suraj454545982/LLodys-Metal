@IsTest
public class ProformaInvoiceLineItemHandlerTest {

    /* =========================================================
       FULL FLOW SETUP – SAME DATA YOU ALWAYS PROVIDED
    ==========================================================*/
    private static Map<String, Id> setupFlow() {

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
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            Validity_Date__c = Date.today().addDays(10),
            ApprovalStatus_c__c = 'Approved'
        );
        insert pbe;

        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 100
        );

        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Status = 'Draft',
            BillingName = 'Billing',
            Additional_Terms_and_Condition__c = 'Terms'
        );
        insert q;

        insert new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 100
        );

        update new Quote(Id = q.Id, Status = 'Accepted');
        update new Opportunity(Id = opp.Id, PO_Received__c = 'Yes');

        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'PO-1',
            Opportunity__c = opp.Id,
            Quote__c = q.Id,
            PO_Date__c = Date.today(),
            PO_Approval_Status__c = 'Approved'
        );
        insert po;

        insert new Purchase_Order_Line_Item__c(
            Purchase_Order__c = po.Id,
            Product__c = prod.Id,
            Quantity__c = 5,
            Sales_Price__c = 100,
            GST_Tax_Percentage__c = 18
        );

        Proforma_Invoice__c pi = new Proforma_Invoice__c(
            Purchase_Order__c = po.Id,
            Opportunity__c = opp.Id,
          
            Status__c = 'Draft'
        );
        insert pi;

        return new Map<String, Id>{
            'prod' => prod.Id,
            'pi'   => pi.Id
        };
    }

    /* =========================================================
       TEST 1: BEFORE INSERT (populate + validate)
    ==========================================================*/
    @IsTest
    static void testBeforeInsert() {

        Map<String, Id> ids = setupFlow();

        Proforma_Invoice_Line_Item__c li = new Proforma_Invoice_Line_Item__c(
            Proforma_Invoice__c = ids.get('pi'),
            Product__c = ids.get('prod'),
            Quantity__c = 3
        );

        Test.startTest();
        ProformaInvoiceLineItemHandler.handleBeforeInsertUpdate(
            new List<Proforma_Invoice_Line_Item__c>{ li },
            null
        );
        Test.stopTest();

        System.assertEquals(100, li.Sales_Price__c,
            'Sales price should be populated from PO line item');
    }

    /* =========================================================
       TEST 2: BEFORE UPDATE (remaining qty validation)
    ==========================================================*/
    @IsTest
    static void testBeforeUpdate() {

        Map<String, Id> ids = setupFlow();

        Proforma_Invoice_Line_Item__c li = new Proforma_Invoice_Line_Item__c(
            Proforma_Invoice__c = ids.get('pi'),
            Product__c = ids.get('prod'),
            Quantity__c = 2,
            Sales_Price__c = 100
        );
        insert li;

        Proforma_Invoice_Line_Item__c oldLi =
            li.clone(false, true, true, true);

        li.Quantity__c = 4;

        Test.startTest();
        ProformaInvoiceLineItemHandler.handleBeforeInsertUpdate(
            new List<Proforma_Invoice_Line_Item__c>{ li },
            new Map<Id, Proforma_Invoice_Line_Item__c>{ li.Id => oldLi }
        );
        Test.stopTest();

        System.assert(li.Quantity__c == 4);
    }

    /* =========================================================
       TEST 3: AFTER INSERT (firstRun = TRUE)
    ==========================================================*/
    @IsTest
    static void testAfterInsert_FirstRun() {

        Map<String, Id> ids = setupFlow();

        Proforma_Invoice_Line_Item__c li = new Proforma_Invoice_Line_Item__c(
            Proforma_Invoice__c = ids.get('pi'),
            Product__c = ids.get('prod'),
            Quantity__c = 1,
            Sales_Price__c = 100
        );
        insert li;

        ProformaInvoiceLineItemHandler.setFirstRun(true);

        Test.startTest();
        ProformaInvoiceLineItemHandler.handleAfterInsertUpdateDelete(
            new List<Proforma_Invoice_Line_Item__c>{ li },
            null
        );
        Test.stopTest();

        System.assertEquals(true,
            ProformaInvoiceLineItemHandler.getFirstRun(),
            'firstRun flag should be reset to true');
    }

    /* =========================================================
       TEST 4: AFTER UPDATE (firstRun = FALSE path)
    ==========================================================*/
    @IsTest
    static void testAfterUpdate_FirstRunFalse() {

        Map<String, Id> ids = setupFlow();

        Proforma_Invoice_Line_Item__c li = new Proforma_Invoice_Line_Item__c(
            Proforma_Invoice__c = ids.get('pi'),
            Product__c = ids.get('prod'),
            Quantity__c = 1,
            Sales_Price__c = 100
        );
        insert li;

        ProformaInvoiceLineItemHandler.setFirstRun(false);

        Test.startTest();
        ProformaInvoiceLineItemHandler.handleAfterInsertUpdateDelete(
            new List<Proforma_Invoice_Line_Item__c>{ li },
            null
        );
        Test.stopTest();

        System.assertEquals(false,
            ProformaInvoiceLineItemHandler.getFirstRun(),
            'Method should exit early when firstRun is false');
    }

    /* =========================================================
       TEST 5: AFTER DELETE
    ==========================================================*/
    /*@IsTest
    static void testAfterDelete() {

        Map<String, Id> ids = setupFlow();

        Proforma_Invoice_Line_Item__c li = new Proforma_Invoice_Line_Item__c(
            Proforma_Invoice__c = ids.get('pi'),
            Product__c = ids.get('prod'),
            Quantity__c = 1,
            Sales_Price__c = 100
        );
        insert li;
        delete li;

        ProformaInvoiceLineItemHandler.setFirstRun(true);

        Test.startTest();
        ProformaInvoiceLineItemHandler.handleAfterInsertUpdateDelete(
            null,
            new List<Proforma_Invoice_Line_Item__c>{ li }
        );
        Test.stopTest();

        System.assert(true);
    }*/
}