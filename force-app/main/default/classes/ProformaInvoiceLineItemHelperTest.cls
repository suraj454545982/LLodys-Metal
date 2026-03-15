@IsTest
public class ProformaInvoiceLineItemHelperTest {

    /* =========================================================
       FULL FLOW SETUP – EXACT SAME FLOW YOU PROVIDED
    ==========================================================*/
    private static Map<String, Id> setupFlow() {

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

        // Purchase Order (Approved)
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

        // Proforma Invoice
        Proforma_Invoice__c pi = new Proforma_Invoice__c(
            Purchase_Order__c = po.Id,
            Opportunity__c = opp.Id,
            Status__c = 'Draft'
        );
        insert pi;

        return new Map<String, Id>{
            'prod' => prod.Id,
            'pi'   => pi.Id,
            'po'   => po.Id
        };
    }

    /* =========================================================
       TEST 1: populateSalesPrice (SUCCESS PATH)
    ==========================================================*/
    @IsTest
    static void testPopulateSalesPrice() {

        Map<String, Id> ids = setupFlow();

        Proforma_Invoice_Line_Item__c li = new Proforma_Invoice_Line_Item__c(
            Proforma_Invoice__c = ids.get('pi'),
            Product__c = ids.get('prod'),
            Quantity__c = 2
        );

        Test.startTest();
        ProformaInvoiceLineItemHelper.populateSalesPrice(
            new List<Proforma_Invoice_Line_Item__c>{ li }
        );
        Test.stopTest();

        System.assertEquals(
            100,
            li.Sales_Price__c,
            'Sales price should be populated from PO line item'
        );
    }

    /* =========================================================
       TEST 2: validateRemainingQuantity – INSERT (PASS)
    ==========================================================*/
    @IsTest
    static void testValidateRemainingQty_InsertPass() {

        Map<String, Id> ids = setupFlow();

        Proforma_Invoice_Line_Item__c li = new Proforma_Invoice_Line_Item__c(
            Proforma_Invoice__c = ids.get('pi'),
            Product__c = ids.get('prod'),
            Quantity__c = 3
        );

        Test.startTest();
        ProformaInvoiceLineItemHelper.validateRemainingQuantity(
            new List<Proforma_Invoice_Line_Item__c>{ li },
            null
        );
        Test.stopTest();

        System.assertEquals(0, li.getErrors().size());
    }

    /* =========================================================
       TEST 3: validateRemainingQuantity – UPDATE (RECALCULATION)
    ==========================================================*/
    @IsTest
    static void testValidateRemainingQty_UpdateRecalc() {

        Map<String, Id> ids = setupFlow();

        Proforma_Invoice_Line_Item__c li = new Proforma_Invoice_Line_Item__c(
            Proforma_Invoice__c = ids.get('pi'),
            Product__c = ids.get('prod'),
            Quantity__c = 2,
            Sales_Price__c = 100,
            Discount__c = 20,
            Freight__c = 10,
            Other_expenses__c = 10,
            Packing_and_Forwarding__c = 5,
            Shipping_and_Handling__c = 5
        );
        insert li;

        Proforma_Invoice_Line_Item__c oldLi =
            li.clone(false, true, true, true);

        li.Quantity__c = 4;

        Test.startTest();
        ProformaInvoiceLineItemHelper.validateRemainingQuantity(
            new List<Proforma_Invoice_Line_Item__c>{ li },
            new Map<Id, Proforma_Invoice_Line_Item__c>{ li.Id => oldLi }
        );
        Test.stopTest();

        System.assertEquals(40, li.Discount__c);
        System.assertEquals(20, li.Freight__c);
    }

    /* =========================================================
       TEST 4: validateRemainingQuantity – EXCEED QTY (ERROR)
    ==========================================================*/
    /*@IsTest
    static void testValidateRemainingQty_ExceedsLimit() {

        Map<String, Id> ids = setupFlow();
		Proforma_Invoice__c pi = [select id from Proforma_Invoice__c limit 1];
        pi.Status__c = 'Approved';
        update pi;
        // Approved PI line consuming full qty
        Proforma_Invoice__c approvedPi = new Proforma_Invoice__c(
            Purchase_Order__c = ids.get('po'),
            //Opportunity__c = pi.Opportunity__c,
            Status__c = 'Approved'
           
        );
        insert approvedPi;

        insert new Proforma_Invoice_Line_Item__c(
            Proforma_Invoice__c = approvedPi.Id,
            Product__c = ids.get('prod'),
            Quantity__c = 5
        );

        Proforma_Invoice_Line_Item__c li = new Proforma_Invoice_Line_Item__c(
            Proforma_Invoice__c = ids.get('pi'),
            Product__c = ids.get('prod'),
            Quantity__c = 1
        );

        Test.startTest();
        ProformaInvoiceLineItemHelper.validateRemainingQuantity(
            new List<Proforma_Invoice_Line_Item__c>{ li },
            null
        );
        Test.stopTest();

        System.assert(li.getErrors().size() > 0);
    }*/

    /* =========================================================
       TEST 5: updateProformaInvoiceTotals
    ==========================================================*/
    @IsTest
    static void testUpdateProformaInvoiceTotals() {
    
        Map<String, Id> ids = setupFlow();
    
        Test.startTest();
    
        // INSERT line item ONLY
        // Let trigger + helper run ONCE
        insert new Proforma_Invoice_Line_Item__c(
            Proforma_Invoice__c = ids.get('pi'),
            Product__c = ids.get('prod'),
            Quantity__c = 1
        );
    
        Test.stopTest();
    
        // ASSERT RESULT
        Proforma_Invoice__c pi = [
            SELECT CGST__c, SGST__c, IGST__c, Total_Amount_New__c
            FROM Proforma_Invoice__c
            WHERE Id = :ids.get('pi')
        ];
    
        System.assertNotEquals(null, pi.Total_Amount_New__c, 'Total should be calculated');
    }

}