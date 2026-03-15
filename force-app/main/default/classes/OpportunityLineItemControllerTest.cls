@isTest
private class OpportunityLineItemControllerTest {

    /* =========================================================
       COMMON TEST DATA
       ========================================================= */
    private static Map<String, Id> createBaseData(Boolean createQuote) {

        // Activate Standard Pricebook
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
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            Category__c = 'Iron Ore',
            Pricebook2Id = stdPbId,
            Plant_and_Shipping_Point__c = '2060'
        );
        insert opp;
        
        

        // Product
        Product2 prod = new Product2(
            Name = 'Iron Ore Product',
            IsActive = true,
            Family = 'Iron Ore',
            Plant__c = '2060'
        );
        insert prod;

        // Pricebook Entry (VALID & APPROVED)
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = prod.Id,
            UnitPrice    = 100,
            IsActive     = true,
            Validity_Date__c = Date.today().addDays(5),
            ApprovalStatus_c__c = 'Approved'
        );
        insert pbe;
        
        OpportunityLineItem baseOli = new OpportunityLineItem(
            OpportunityId     = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity          = 1,
            UnitPrice         = 100
        );
        insert baseOli;

        // Quote (optional)
        Quote q;
        if (createQuote) {
            q = new Quote(
                Name = 'Test Quote',
                OpportunityId = opp.Id,
                Status = 'Draft',
                Pricebook2Id = stdPbId,
                BillingName = 'sample',
                Additional_Terms_and_Condition__c = 'sample terms and conditions'
            );
            insert q;
        }

        return new Map<String, Id>{
            'opp' => opp.Id,
            'prod' => prod.Id,
            'pbe' => pbe.Id
        };
    }

    /* =========================================================
       BLOCK OLI CREATION WHEN QUOTE EXISTS
       ========================================================= */
    @isTest
    static void testBlockOLICreation() {

        Map<String, Id> ids = createBaseData(true);

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = ids.get('opp'),
            PricebookEntryId = ids.get('pbe'),
            Quantity = 1,
            UnitPrice = 100
        );

        Test.startTest();
        OpportunityLineItemController.blockOLICreationWhenQuoteExists(
            new List<OpportunityLineItem>{ oli }
        );
        Test.stopTest();

        System.assert(
            oli.getErrors().size() > 0,
            'OLI creation must be blocked when Quote exists'
        );
    }

    /* =========================================================
       BLOCK OLI DELETE WHEN QUOTE EXISTS
       ========================================================= */
    @isTest
    static void testBlockOLIDelete() {
    
        Map<String, Id> ids = createBaseData(true);
    
        // Simulate existing OLI (already in DB from setup)
        OpportunityLineItem existingOli = [
            SELECT Id, OpportunityId
            FROM OpportunityLineItem
            WHERE OpportunityId = :ids.get('opp')
            LIMIT 1
        ];
    
        Test.startTest();
        OpportunityLineItemController.blockOLIDeleteWhenQuoteExists(
            new List<OpportunityLineItem>{ existingOli }
        );
        Test.stopTest();
    
        System.assert(
            existingOli.getErrors().size() > 0,
            'OLI delete must be blocked when Quote exists'
        );
    }


    /* =========================================================
       VALID CATEGORY + VALID PRICEBOOK
       ========================================================= */
    @isTest
    static void testValidateCategoriesSuccess() {

        Map<String, Id> ids = createBaseData(false);

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = ids.get('opp'),
            PricebookEntryId = ids.get('pbe'),
            Quantity = 1,
            UnitPrice = 100
        );

        Test.startTest();
        OpportunityLineItemController.validateCategories(
            new List<OpportunityLineItem>{ oli }
        );
        Test.stopTest();

        
    }

    /* =========================================================
       CATEGORY MISMATCH
       ========================================================= */
    @isTest
    static void testCategoryMismatch() {

        Map<String, Id> ids = createBaseData(false);

        // Change Product Family
        Product2 prod = [SELECT Id, Family FROM Product2 WHERE Id = :ids.get('prod')];
        prod.Family = 'Coal';
        update prod;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = ids.get('opp'),
            PricebookEntryId = ids.get('pbe'),
            Quantity = 1,
            UnitPrice = 100
        );

        Test.startTest();
        OpportunityLineItemController.validateCategories(
            new List<OpportunityLineItem>{ oli }
        );
        Test.stopTest();

        
    }

    /* =========================================================
       MISSING DATA BRANCHES
       ========================================================= */
    @isTest
    static void testMissingDataBranches() {

        OpportunityLineItem oli = new OpportunityLineItem();

        Test.startTest();
        OpportunityLineItemController.validateCategories(
            new List<OpportunityLineItem>{ oli }
        );
        Test.stopTest();

        System.assert(
            oli.getErrors().size() > 0,
            'Missing data branch must throw errors'
        );
    }
}