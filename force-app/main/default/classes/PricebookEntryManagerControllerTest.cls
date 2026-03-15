@IsTest
public class PricebookEntryManagerControllerTest {

    @testSetup
    static void setupData() {

        // 1️⃣ Activate Standard Pricebook
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(
            Id = stdPbId,
            IsActive = true,
            validity_date__c = system.today()
        );

        // 2️⃣ Create Products
        List<Product2> products = new List<Product2>();
        for (Integer i = 1; i <= 5; i++) {
            products.add(new Product2(
                Name = 'Test Product ' + i,
                IsActive = true,
                Family = 'Iron Ore',
                Plant__c = '2045-MANIKGARH-STOCK YARD'
            ));
        }
        insert products;

        // 3️⃣ Create Standard Pricebook Entries (MANDATORY)
        List<PricebookEntry> stdPBEs = new List<PricebookEntry>();
        for (Product2 p : products) {
            stdPBEs.add(new PricebookEntry(
                Pricebook2Id = stdPbId,
                Product2Id   = p.Id,
                UnitPrice    = 100,
                IsActive     = true,
                UseStandardPrice = false
            ));
        }
        insert stdPBEs;

        // 4️⃣ Create Custom Pricebook
        Pricebook2 customPb = new Pricebook2(
            Name = 'Custom Test Pricebook',
            IsActive = true,
            validity_date__c = system.today()
        );
        insert customPb;

        // 5️⃣ Add ONE product to custom pricebook (for fetch tests)
        insert new PricebookEntry(
            Pricebook2Id = customPb.Id,
            Product2Id   = products[0].Id,
            UnitPrice    = 150,
            Freight__c   = 10,
            Product_Price__c = 140,
            IsActive     = true,
            UseStandardPrice = false
        );
    }

    // ------------------------------
    // getPricebookEntries TEST
    // ------------------------------
    @IsTest
    static void testGetPricebookEntries() {

        Pricebook2 pb = [
            SELECT Id FROM Pricebook2 WHERE Name = 'Custom Test Pricebook' LIMIT 1
        ];

        Test.startTest();
        Map<String, Object> result =
            PricebookEntryManagerController.getPricebookEntries(
                pb.Id,
                10,
                null,
                'Test'
            );
        Test.stopTest();

        System.assert(result.containsKey('entries'));
        System.assert(result.containsKey('totalCount'));

        List<PricebookEntry> entries =
            (List<PricebookEntry>) result.get('entries');

        System.assert(entries.size() > 0, 'Entries should be returned');
    }

    // ------------------------------
    // getAllProducts TEST
    // ------------------------------
    @IsTest
    static void testGetAllProducts() {

        Pricebook2 pb = [
            SELECT Id FROM Pricebook2 WHERE Name = 'Custom Test Pricebook' LIMIT 1
        ];

        Test.startTest();
        List<Product2> products =
            PricebookEntryManagerController.getAllProducts(
                pb.Id,
                'Test',
                10,
                null
            );
        Test.stopTest();

        System.assert(products.size() > 0, 'Available products should be returned');

        // Ensure product already added to PB is excluded
        for (Product2 p : products) {
            System.assertNotEquals('Test Product 1', p.Name);
        }
    }

    // ------------------------------
    // addSelectedProducts TEST
    // ------------------------------
    @IsTest
    static void testAddSelectedProducts() {

        Pricebook2 pb = [
            SELECT Id FROM Pricebook2 WHERE Name = 'Custom Test Pricebook' LIMIT 1
        ];

        Product2 prod = [
            SELECT Id FROM Product2 WHERE Name = 'Test Product 2' LIMIT 1
        ];

        List<Map<String, Object>> products = new List<Map<String, Object>>();

        Map<String, Object> pMap = new Map<String, Object>{
            'Id' => prod.Id,
            'Freight__c' => 20,
            'Product_Price__c' => 180
        };
        products.add(pMap);

        Test.startTest();
        PricebookEntryManagerController.addSelectedProducts(
            pb.Id,
            products
        );
        Test.stopTest();

        PricebookEntry insertedPbe = [
            SELECT UnitPrice, Freight__c, Product_Price__c
            FROM PricebookEntry
            WHERE Pricebook2Id = :pb.Id
            AND Product2Id = :prod.Id
            LIMIT 1
        ];

        System.assertEquals(200, insertedPbe.UnitPrice);
        System.assertEquals(20, insertedPbe.Freight__c);
        System.assertEquals(180, insertedPbe.Product_Price__c);
    }

    // ------------------------------
    // Exception TEST
    // ------------------------------
    @IsTest
    static void testAddSelectedProducts_Exception() {

        Pricebook2 pb = [
            SELECT Id FROM Pricebook2 WHERE Name = 'Custom Test Pricebook' LIMIT 1
        ];

        Test.startTest();
        try {
            PricebookEntryManagerController.addSelectedProducts(pb.Id, null);
            System.assert(false, 'Exception should have been thrown');
        } catch (AuraHandledException e) {
           // System.assert(e.getMessage().contains('Products list is empty'));
        }
        Test.stopTest();
    }
}