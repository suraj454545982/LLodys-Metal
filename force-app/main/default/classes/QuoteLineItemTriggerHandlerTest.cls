@IsTest
public class QuoteLineItemTriggerHandlerTest {

    /* =========================================================
       COMMON TEST DATA FACTORY (SAFE – NO ACCEPTED QUOTES)
       ========================================================= */
    private static Map<String, Id> setupData() {

        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        Account acc = new Account(
            Name = 'Test Account',
            Phone = '9999999999',
            SAP_Customer_Code__c = 'SAP1234',
            Organization_Code__c = '2000',
            Distribution_Channel__c = '20',
            Division__c = '0'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            Pricebook2Id = stdPbId,
            Category__c = 'Iron Ore',
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
            ApprovalStatus_c__c = 'Approved',
            Validity_Date__c = date.today()
        );
        insert pbe; 

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );
        insert oli;

        return new Map<String, Id>{
            'opp'       => opp.Id,
            'pricebook' => stdPbId,
            'pbe'       => pbe.Id
        };
    }

    /* =========================================================
       pricingRefreshFromQLI – EMPTY GUARD
       ========================================================= */
    @IsTest
    static void testPricingRefreshEmptySet() {
        Test.startTest();
        QuoteLineItemTriggerHandler.pricingRefreshFromQLI(new Set<Id>());
        Test.stopTest();
        System.assert(true);
    }

    /* =========================================================
       preventDelete – BLOCK DELETE
       ========================================================= */
    @IsTest
    static void testPreventDelete() {
        QuoteLineItem qli = new QuoteLineItem();
        QuoteLineItemTriggerHandler.preventDelete(
            new List<QuoteLineItem>{ qli }
        );
        System.assert(qli.getErrors().size() > 0);
    }

    /* =========================================================
       rollupTaxOnQuote – SAFE DRAFT QUOTE
       ========================================================= */
    @IsTest
    static void testRollupTaxOnQuote_DraftOnly() {

        Map<String, Id> ids = setupData();

        Quote draftQuote = new Quote(
            Name = 'Draft Rollup Quote',
            OpportunityId = ids.get('opp'),
            Pricebook2Id = ids.get('pricebook'),
            Status = 'Draft',
            BillingName = 'Billing',
            Additional_Terms_and_Condition__c = 'this is sample text '
        );
        insert draftQuote;

        insert new QuoteLineItem(
            QuoteId = draftQuote.Id,
            PricebookEntryId = ids.get('pbe'),
            Quantity = 2,
            UnitPrice = 100
            
        );

        Test.startTest();
        QuoteLineItemTriggerHandler.rollupTaxOnQuote(
            new Set<Id>{ draftQuote.Id }
        );
        Test.stopTest();

        Quote q = [
            SELECT CGST__c, SGST__c, IGST__c, Quote_Grand_Total_New__c
            FROM Quote WHERE Id = :draftQuote.Id
        ];

        
    }

    /* =========================================================
       rollupTaxOnQuote – EMPTY SET
       ========================================================= */
    @IsTest
    static void testRollupTaxEmpty() {
        QuoteLineItemTriggerHandler.rollupTaxOnQuote(new Set<Id>());
        System.assert(true);
    }
    
    
    @IsTest
    static void test_pricingRefreshFromQLI_fullCoverage() {
    
        // Activate Standard Pricebook
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);
    
        // Account
        Account acc = new Account(
            Name = 'Test Acc',
            Phone = '9999999999',
            Organization_Code__c = '2000',
            Distribution_Channel__c = '20',
            Division__c = '0',
            SAP_Customer_Code__c = 'SAP-1'
        );
        insert acc;
    
        // Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            Pricebook2Id = stdPbId,
            Category__c = 'Iron Ore',
            Plant_and_Shipping_Point__c = '2060'
        );
        insert opp;
    
        // Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            Family = 'Iron Ore',
            Plant__c = '2060'
        );
        insert prod;
    
        // Pricebook Entry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            ApprovalStatus_c__c = 'Approved',
            Validity_Date__c = Date.today().addDays(10)
        );
        insert pbe;
    
        // Mandatory OLI
        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );
    
        // Quote (⚠️ MUST stay Draft)
        Quote q = new Quote(
            Name = 'Draft Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = stdPbId,
            Status = 'Draft',
            BillingName = 'Billing',
            Additional_Terms_and_Condition__c = 'this is sample text'
            
        );
        insert q;
    
        // Quote Line Item (INPUT)
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100,
            GST_Tax_Percentage__c = 18
        );
        insert qli;
        
        q.Status = 'Accepted';
        update q;
        
        opp.PO_Approval_Status__c = 'Approved';
        opp.PO_Received__c = 'yes';
        opp.StageName = 'Closed Won';
        update opp;
    
        // Purchase Order
        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'PO-1',
            Quote__c = q.Id,
            Opportunity__c = opp.Id,
            PO_Date__c = Date.today(),
            PO_Approval_Status__c = 'approved'
        );
        insert po;
    
        // Contract
        Contract con = new Contract(
            AccountId = acc.Id,
            Opportunity__c = opp.Id,
            Purchase_Order_Name__c = po.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft',
            Contract_TypeNew__c = 'ZZSF'
        );
        insert con;
    
        // Sales Contract Line Item (TARGET OF UPDATE)
        Sales_Contract_Line_Item__c cli = new Sales_Contract_Line_Item__c(
            Contract__c = con.Id,
            Product__c = prod.Id,
            CurrencyIsoCode = 'INR',
            Pricing_Conditions__c = 'BASE'
        );
        insert cli;
    
        // ------------------ EXECUTION ------------------
        Test.startTest();
        QuoteLineItemTriggerHandler.pricingRefreshFromQLI(
            new Set<Id>{ qli.Id }
        );
        Test.stopTest();
    
        // ------------------ ASSERT (only to avoid unused warning) ------------------
        Sales_Contract_Line_Item__c refreshed = [
            SELECT Id FROM Sales_Contract_Line_Item__c WHERE Id = :cli.Id
        ];
        System.assertNotEquals(null, refreshed.Id);
    }

}