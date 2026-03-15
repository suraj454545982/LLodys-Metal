@IsTest
private class SalesContractLineItemTriggerHandlerTest {

    @TestSetup
    static void setupData() {
        
         // ---------------- PRICEBOOK ----------------
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        // ---------------- ACCOUNT ----------------
        Account acc = new Account(
            Name = 'Test Account',
            Phone = '9999999999',
            Organization_Code__c = '2000',
            Distribution_Channel__c = '20',
            Division__c = '0',
            SAP_Customer_Code__c = 'SAP1022'
        );
        insert acc;

        // ---------------- OPPORTUNITY ----------------
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            Category__c = 'Iron Ore',
            Quote_status__c = 'Accepted',
            Plant_and_Shipping_Point__c = '2060',
            PO_Received__c = 'Yes'
        );
        insert opp;

        // ---------------- PRODUCT ----------------
        Product2 prod = new Product2(
            Name = 'Iron Ore',
            ProductCode = 'MAT-001',
            IsActive = true,
            Family = 'Iron Ore',
            Plant__c = '2060'
        );
        insert prod;

        // ---------------- PRICEBOOK ENTRY ----------------
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
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );

        // ---------------- QUOTE ----------------
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
            Quantity = 1,
            UnitPrice = 100
        );

        update new Quote(Id = q.Id, Status = 'Accepted');

        // ---------------- PURCHASE ORDER ----------------
        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'PO-001',
            Quote__c = q.Id,
            Opportunity__c = opp.Id,
            PO_Approval_Status__c = 'approved',
            PO_Date__c = Date.today()
        );
        insert po;

        // ---------------- CONTRACT (SAP CREATED) ----------------
        Contract con = new Contract(
            Contract_TypeNew__c = 'ZZSF',
            Opportunity__c = opp.Id,
            Purchase_Order_Name__c = po.Id,
            
            SAP_Sales_Contract_Number__c = 'SAP-CON-1001'
        );
        insert con;

        // ---------- PO Line Item ----------
        Purchase_Order_Line_Item__c pli = new Purchase_Order_Line_Item__c(
            Purchase_Order__c = po.Id,
            Product__c = prod.Id,
            Quantity__c = 100,
            Sales_Price__c = 50,
            Discount__c = 10,
            Freight__c = 5,
            Other_Expenses__c = 2,
            Shipping_and_Handling__c = 3,
            Packing_and_Forwarding__c = 4
        );
        insert pli;
    }

    // ------------------------------------------------------------------
    // 1. BLOCKED LINE ITEM EDIT TEST
    // ------------------------------------------------------------------
    @IsTest
    static void testPreventEditOnBlockedLineItem() {

        Sales_Contract_Line_Item__c cli = new Sales_Contract_Line_Item__c(
            Contract__c = [SELECT Id FROM Contract LIMIT 1].Id,
            Product__c = [SELECT Id FROM Product2 LIMIT 1].Id,
            Quantity__c = 10,
            Reason_for_Rejection__c = '58'
        );
        insert cli;

        Sales_Contract_Line_Item__c oldCli = cli.clone(false, true, true, true);
        cli.Quantity__c = 20; // illegal edit

        Test.startTest();
        SalesContractLineItemTriggerHandler.preventEditOnBlockedLineItems(
            new List<Sales_Contract_Line_Item__c>{ cli },
            new Map<Id, Sales_Contract_Line_Item__c>{ cli.Id => oldCli }
        );
        Test.stopTest();

        System.assert(cli.getErrors().size() > 0);
    }

    // ------------------------------------------------------------------
    // 2. PREVENT REJECTION BEFORE SAP SYNC
    // ------------------------------------------------------------------
    @IsTest
    static void testPreventRejectionBeforeSAPSync() {

        Contract con = [SELECT Id FROM Contract LIMIT 1];

        Sales_Contract_Line_Item__c cli = new Sales_Contract_Line_Item__c(
            Contract__c = con.Id,
            Product__c = [SELECT Id FROM Product2 LIMIT 1].Id,
            Quantity__c = 5,
            Reason_for_Rejection__c = 'R1'
        );

        Sales_Contract_Line_Item__c oldCli = cli.clone(false, true, true, true);

        Test.startTest();
        SalesContractLineItemTriggerHandler.preventRejectionReasonBeforeSAPSync(
            new List<Sales_Contract_Line_Item__c>{ cli },
            new Map<Id, Sales_Contract_Line_Item__c>{ cli.Id => oldCli }
        );
        Test.stopTest();

        //System.assertEquals(null, cli.Reason_for_Rejection__c);
    }

    // ------------------------------------------------------------------
    // 3. POPULATE LIST PRICE
    // ------------------------------------------------------------------
    @IsTest
    static void testPopulateListPrice() {

        Contract con = [SELECT Id FROM Contract LIMIT 1];
        Product2 prod = [SELECT Id, ProductCode FROM Product2 LIMIT 1];

        Sales_Contract_Line_Item__c cli = new Sales_Contract_Line_Item__c(
            Contract__c = con.Id,
            Product__c = prod.Id,
            Quantity__c = 10
        );

        Test.startTest();
        SalesContractLineItemTriggerHandler.populateListPrice(
            new List<Sales_Contract_Line_Item__c>{ cli }
        );
        Test.stopTest();

        System.assertNotEquals(null, cli.List_Price__c);
        System.assertEquals(500, cli.Amount__c);
    }

    // ------------------------------------------------------------------
    // 4. RECALCULATE & LIMIT VALIDATION
    // ------------------------------------------------------------------
    @IsTest
    static void testRecalculateAmountAndValidateLimit() {

        Contract con = [SELECT Id FROM Contract LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];

        Sales_Contract_Line_Item__c cli = new Sales_Contract_Line_Item__c(
            Contract__c = con.Id,
            Product__c = prod.Id,
            Quantity__c = 5,
            List_Price__c = 50
        );
        insert cli;

        Sales_Contract_Line_Item__c oldCli = cli.clone(false, true, true, true);
        cli.Quantity__c = 10;

        Test.startTest();
        SalesContractLineItemTriggerHandler.recalculateAmountAndValidateLimit(
            new List<Sales_Contract_Line_Item__c>{ cli },
            new Map<Id, Sales_Contract_Line_Item__c>{ cli.Id => oldCli }
        );
        Test.stopTest();

        System.assertEquals(500, cli.Amount__c);
    }

    // ------------------------------------------------------------------
    // 5. TAX ROLLUP
    // ------------------------------------------------------------------
    @IsTest
    static void testRollupTaxOnContract() {

        Contract con = [SELECT Id FROM Contract LIMIT 1];

        Sales_Contract_Line_Item__c cli = new Sales_Contract_Line_Item__c(
            Contract__c = con.Id
            
        );
        insert cli;

        Test.startTest();
        SalesContractLineItemTriggerHandler.rollupTaxOnContract(
            new Set<Id>{ con.Id }
        );
        Test.stopTest();


    }
}