@IsTest
public class ProductTriggerHandlerTest {

    @TestSetup
    static void setupData() {

        // -------------------------------------------------
        // Activate Standard Pricebook
        // -------------------------------------------------
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(
            Id = stdPbId,
            IsActive = true
        );

        // -------------------------------------------------
        // Product
        // -------------------------------------------------
        Product2 prod = new Product2(
            Name = 'Test Product',
            ProductCode = 'MAT-001',
            IsActive = true,
            Material_Blocked__c = 'No'
        );
        insert prod;

        // -------------------------------------------------
        // Pricebook Entry
        // -------------------------------------------------
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = prod.Id,
            UnitPrice    = 100,
            IsActive     = true
        );
        insert pbe;
    }

    // -------------------------------------------------
    // TEST: Material_Blocked__c = Yes → Deactivate
    // -------------------------------------------------
    @IsTest
    static void testDeactivateProductAndPricebookEntry() {

        Product2 prod = [
            SELECT Id, IsActive, Material_Blocked__c
            FROM Product2
            LIMIT 1
        ];

        Test.startTest();

        prod.Material_Blocked__c = 'Yes';
        update prod; // 🔥 beforeUpdate + afterUpdate fire

        Test.stopTest();

        // Verify Product
        Product2 updatedProd = [
            SELECT IsActive
            FROM Product2
            WHERE Id = :prod.Id
        ];
        System.assertEquals(false, updatedProd.IsActive);

        // Verify PricebookEntry
        PricebookEntry pbe = [
            SELECT IsActive
            FROM PricebookEntry
            WHERE Product2Id = :prod.Id
            LIMIT 1
        ];
        System.assertEquals(false, pbe.IsActive);
    }

    // -------------------------------------------------
    // TEST: Material_Blocked__c = No → Activate
    // -------------------------------------------------
    @IsTest
    static void testActivateProductAndPricebookEntry() {

        Product2 prod = [
            SELECT Id, IsActive, Material_Blocked__c
            FROM Product2
            LIMIT 1
        ];

        // First deactivate to ensure real transition
        prod.Material_Blocked__c = 'Yes';
        update prod;

        Test.startTest();

        prod.Material_Blocked__c = 'No';
        update prod; // 🔥 beforeUpdate + afterUpdate fire again

        Test.stopTest();

        // Verify Product
        Product2 updatedProd = [
            SELECT IsActive
            FROM Product2
            WHERE Id = :prod.Id
        ];
        System.assertEquals(true, updatedProd.IsActive);

        // Verify PricebookEntry
        PricebookEntry pbe = [
            SELECT IsActive
            FROM PricebookEntry
            WHERE Product2Id = :prod.Id
            LIMIT 1
        ];
        System.assertEquals(true, pbe.IsActive);
    }
}