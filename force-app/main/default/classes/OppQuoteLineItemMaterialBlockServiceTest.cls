@isTest
private class OppQuoteLineItemMaterialBlockServiceTest {

    /* =========================================================
       COMMON PRODUCT DATA
       ========================================================= */
    private static Map<String, Id> createProducts() {

        Product2 openProd = new Product2(
            Name = 'Open Product',
            ProductCode = 'OPEN-01',
            Description = 'Open Desc',
            IsActive = true,
            Material_Blocked__c = 'No',
            Plant__c ='2050-HEDRI- BENFICATION PLANT(BHQ)'
        );

        Product2 blockedProd = new Product2(
            Name = 'Blocked Product',
            ProductCode = 'BLK-01',
            Description = 'Blocked Desc',
            IsActive = true,
            Material_Blocked__c = 'Yes',
            Plant__c ='2060-GOA - PELLET'
        );

        insert new List<Product2>{ openProd, blockedProd };

        return new Map<String, Id>{
            'open' => openProd.Id,
            'blocked' => blockedProd.Id
        };
    }

    /* =========================================================
       OLI – INSERT (BLOCKED PRODUCT)
       ========================================================= */
    @isTest
    static void testOLIInsertBlocked() {

        Id blockedProdId = createProducts().get('blocked');

        OpportunityLineItem oli = new OpportunityLineItem();
        oli.put('Product2Id', blockedProdId);

        Test.startTest();
        OppQuoteLineItemMaterialBlockService.preventAddingOrUpdatingBlockedProducts(
            new List<SObject>{ oli },
            true
        );
        Test.stopTest();

        System.assert(
            oli.getErrors().size() > 0,
            'OLI insert should be blocked'
        );
    }

    /* =========================================================
       OLI – UPDATE (BLOCKED PRODUCT)
       ========================================================= */
    @isTest
    static void testOLIUpdateBlocked() {

        Id blockedProdId = createProducts().get('blocked');

        OpportunityLineItem oli = new OpportunityLineItem();
        oli.put('Product2Id', blockedProdId);

        Test.startTest();
        OppQuoteLineItemMaterialBlockService.preventAddingOrUpdatingBlockedProducts(
            new List<SObject>{ oli },
            false
        );
        Test.stopTest();

        System.assert(
            oli.getErrors().size() > 0,
            'OLI update should be blocked'
        );
    }

    /* =========================================================
       QLI – INSERT (BLOCKED PRODUCT)
       ========================================================= */
    @isTest
    static void testQLIInsertBlocked() {

        Id blockedProdId = createProducts().get('blocked');

        QuoteLineItem qli = new QuoteLineItem();
        qli.put('Product2Id', blockedProdId);

        Test.startTest();
        OppQuoteLineItemMaterialBlockService.preventAddingOrUpdatingBlockedProducts(
            new List<SObject>{ qli },
            true
        );
        Test.stopTest();

        System.assert(
            qli.getErrors().size() > 0,
            'QLI insert should be blocked'
        );
    }

    /* =========================================================
       QLI – UPDATE (BLOCKED PRODUCT)
       ========================================================= */
    @isTest
    static void testQLIUpdateBlocked() {

        Id blockedProdId = createProducts().get('blocked');

        QuoteLineItem qli = new QuoteLineItem();
        qli.put('Product2Id', blockedProdId);

        Test.startTest();
        OppQuoteLineItemMaterialBlockService.preventAddingOrUpdatingBlockedProducts(
            new List<SObject>{ qli },
            false
        );
        Test.stopTest();

        System.assert(
            qli.getErrors().size() > 0,
            'QLI update should be blocked'
        );
    }

    /* =========================================================
       NON-BLOCKED PRODUCT (NO ERROR)
       ========================================================= */
    @isTest
    static void testNonBlockedProductAllowed() {

        Id openProdId = createProducts().get('open');

        OpportunityLineItem oli = new OpportunityLineItem();
        oli.put('Product2Id', openProdId);

        Test.startTest();
        OppQuoteLineItemMaterialBlockService.preventAddingOrUpdatingBlockedProducts(
            new List<SObject>{ oli },
            true
        );
        Test.stopTest();

        System.assertEquals(
            0,
            oli.getErrors().size(),
            'Non-blocked product should be allowed'
        );
    }

    /* =========================================================
       GUARD CLAUSES
       ========================================================= */
    @isTest
    static void testGuardClauses() {

        Test.startTest();
        OppQuoteLineItemMaterialBlockService.preventAddingOrUpdatingBlockedProducts(
            null,
            true
        );
        OppQuoteLineItemMaterialBlockService.preventAddingOrUpdatingBlockedProducts(
            new List<SObject>(),
            true
        );
        Test.stopTest();

        System.assert(true, 'Guard clauses executed');
    }
}