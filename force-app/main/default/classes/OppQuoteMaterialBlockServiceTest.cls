@isTest
private class OppQuoteMaterialBlockServiceTest {

    /* ---------------------------------------------------------
       Common Test Data
    ----------------------------------------------------------*/
    private static Map<String, Id> setupData() {

        Id stdPbId = Test.getStandardPricebookId();
    
        // Activate Standard Pricebook (no SOQL)
        update new Pricebook2(
            Id = stdPbId,
            IsActive = true
        );
    
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            Pricebook2Id = stdPbId,
            Category__c = 'Iron Ore',
            Plant_and_Shipping_Point__c = '2060'
        );
        insert opp;
    
        // -------------------------------
        // Products (NOT blocked initially)
        // -------------------------------
        Product2 prodOpen = new Product2(
            Name = 'Open Product',
            ProductCode = 'OPEN-01',
            Description = 'Open Product',
            IsActive = true,
            Material_Blocked__c = 'No',
            Plant__c = '2060',
            Family = 'Iron Ore'
        );
    
        Product2 prodBlocked = new Product2(
            Name = 'Blocked Product',
            ProductCode = 'BLK-01',
            Description = 'Blocked Product',
            IsActive = true,
            Material_Blocked__c = 'No', // IMPORTANT
            Plant__c = '2060',
            Family = 'Iron Ore'
        );
    
        insert new List<Product2>{ prodOpen, prodBlocked };
    
        // -------------------------------
        // Pricebook Entries
        // -------------------------------
        PricebookEntry pbeOpen = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = prodOpen.Id,
            UnitPrice    = 100,
            IsActive     = true,
            Validity_Date__c = Date.today(),
            ApprovalStatus_c__c = 'Approved'
        );
    
        PricebookEntry pbeBlocked = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = prodBlocked.Id,
            UnitPrice    = 200,
            IsActive     = true,
            Validity_Date__c = Date.today(),
            ApprovalStatus_c__c = 'Approved'
        );
    
        insert new List<PricebookEntry>{ pbeOpen, pbeBlocked };
    
        
    
        // ---------------------------------------
        // INSERT OLI (NOW APPROVED & VALID)
        // ---------------------------------------
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId     = opp.Id,
            PricebookEntryId = pbeBlocked.Id,
            Quantity          = 1,
            UnitPrice         = 200
        );
        insert oli;
    
        Quote quote = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Status = 'Draft',
            Pricebook2Id = stdPbId,
            BillingName = 'billing name',
            Additional_Terms_and_Condition__c = 'this is sample text'
        );
        insert quote;
    
        // ---------------------------------------
        // INSERT QLI (NOW APPROVED & VALID)
        // ---------------------------------------
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId           = quote.Id,
            PricebookEntryId = pbeBlocked.Id,
            Quantity          = 1,
            UnitPrice         = 200
        );
        insert qli;
    
        // ---------------------------------------
        // 🔥 NOW BLOCK THE PRODUCT
        // ---------------------------------------
        prodBlocked.Material_Blocked__c = 'Yes';
        update prodBlocked;
    
        return new Map<String, Id>{
            'opp'   => opp.Id,
            'quote' => quote.Id
        };
    }


    /* ---------------------------------------------------------
       Opportunity BEFORE UPDATE – Blocked OLI
    ----------------------------------------------------------*/
    @isTest
    static void testOpportunityBeforeUpdateBlocked() {

        Id oppId = setupData().get('opp');

        Opportunity oppNew = [
            SELECT Id FROM Opportunity WHERE Id = :oppId
        ];

        Opportunity oppOld = oppNew.clone(false, true, false, false);
        oppOld.Id = oppNew.Id;

        List<SObject> newList = new List<SObject>{ oppNew };
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ oppOld.Id => oppOld };

        Test.startTest();
        OppQuoteMaterialBlockService.validateOnInsertAndUpdate(newList, oldMap);
        Test.stopTest();

        System.assert(
            oppNew.getErrors().size() > 0,
            'Opportunity should be blocked due to blocked product'
        );
    }

    /* ---------------------------------------------------------
       Quote BEFORE INSERT – Blocked OLI on Opportunity
    ----------------------------------------------------------*/
    @isTest
    static void testQuoteBeforeInsertBlockedFromOpp() {

        Map<String, Id> ids = setupData();

        Quote q = new Quote(
            Name = 'New Quote',
            OpportunityId = ids.get('opp'),
            Status = 'Draft',
            Pricebook2Id = Test.getStandardPricebookId()
        );

        Test.startTest();
        OppQuoteMaterialBlockService.validateOnInsertAndUpdate(
            new List<SObject>{ q },
            null
        );
        Test.stopTest();

        System.assert(
            q.getErrors().size() > 0,
            'Quote insert should be blocked due to blocked OLI'
        );
    }

    /* ---------------------------------------------------------
       Quote BEFORE UPDATE – Blocked QLI
    ----------------------------------------------------------*/
    @isTest
    static void testQuoteBeforeUpdateBlockedQLI() {

        Id quoteId = setupData().get('quote');

        Quote qNew = [
            SELECT Id, Status FROM Quote WHERE Id = :quoteId
        ];

        Quote qOld = qNew.clone(false, true, false, false);
        qOld.Id = qNew.Id;

        qNew.Name = 'Updated Quote';

        Test.startTest();
        OppQuoteMaterialBlockService.validateOnInsertAndUpdate(
            new List<SObject>{ qNew },
            new Map<Id, SObject>{ qOld.Id => qOld }
        );
        Test.stopTest();

        System.assert(
            qNew.getErrors().size() > 0,
            'Quote update should be blocked due to blocked QLI'
        );
    }

    /* ---------------------------------------------------------
       Prevent Quote ACCEPTED when Opp has blocked OLI
    ----------------------------------------------------------*/
    @isTest
    static void testPreventQuoteAcceptance() {

        Id quoteId = setupData().get('quote');

        Quote qOld = [
            SELECT Id, Status, OpportunityId FROM Quote WHERE Id = :quoteId
        ];

        Quote qNew = qOld.clone(false, true, false, false);
        qNew.Id = qOld.Id;
        qNew.Status = 'Accepted';

        Test.startTest();
        OppQuoteMaterialBlockService.preventQuoteAcceptanceIfOppHasBlockedProducts(
            new List<Quote>{ qNew },
            new Map<Id, Quote>{ qOld.Id => qOld }
        );
        Test.stopTest();

        System.assert(
            qNew.getErrors().size() > 0,
            'Quote should not be accepted due to blocked products'
        );
    }

    /* ---------------------------------------------------------
       Guard clauses – Empty input
    ----------------------------------------------------------*/
    @isTest
    static void testEmptyGuards() {

        Test.startTest();
        OppQuoteMaterialBlockService.validateOnInsertAndUpdate(null, null);
        OppQuoteMaterialBlockService.validateOnInsertAndUpdate(new List<SObject>(), null);
        OppQuoteMaterialBlockService.preventQuoteAcceptanceIfOppHasBlockedProducts(
            new List<Quote>(),
            null
        );
        Test.stopTest();

        System.assert(true, 'Guard clauses executed');
    }
}