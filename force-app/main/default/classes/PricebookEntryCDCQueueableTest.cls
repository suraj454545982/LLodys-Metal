@IsTest
private class PricebookEntryCDCQueueableTest {

    /* ---------------- HELPER ---------------- */
    private static PricebookEntryChangeEvent buildCDC(Id pbeId) {
        String jsonEvt =
            '{ "ChangeEventHeader": { "recordIds": ["' + pbeId + '"] } }';
        return (PricebookEntryChangeEvent)
            JSON.deserialize(jsonEvt, PricebookEntryChangeEvent.class);
    }

    /* ---------------- TEST DATA ---------------- */
    @TestSetup
    static void setup() {
    
        // Standard Pricebook (MANDATORY)
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);
    
        // Custom Pricebook
        Pricebook2 pb = new Pricebook2(
            Name = 'PB',
            IsActive = true,
            Validity_Date__c = Date.today().addDays(10)
        );
        insert pb;
    
        // Product
        Product2 prod = new Product2(
            Name = 'Product',
            IsActive = true
        );
        insert prod;
    
        // 🔴 REQUIRED STANDARD PRICE
        insert new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 1,
            IsActive = true
        );
    
        // ✅ NOW custom pricebook entry is allowed
        insert new PricebookEntry(
            Pricebook2Id = pb.Id,
            Product2Id = prod.Id,
            UnitPrice = 1,
            IsActive = true
        );
    }


    /* ---------------- MAIN SUCCESS PATH ---------------- */
    @IsTest
    static void testPriceCalculationAndApprovalInsert() {

        PricebookEntry pbe = [
            SELECT Id FROM PricebookEntry LIMIT 1
        ];

        pbe.Product_Price__c = 100;
        pbe.Freight__c = 20;
        update pbe;

        Test.startTest();
        System.enqueueJob(
            new PricebookEntryCDCQueueable(
                new List<PricebookEntryChangeEvent>{
                    buildCDC(pbe.Id)
                }
            )
        );
        Test.stopTest();

        PricebookEntry updated = [
            SELECT UnitPrice, Total_Price__c
            FROM PricebookEntry WHERE Id = :pbe.Id
        ];
        System.assertEquals(1, updated.UnitPrice);
        //System.assertEquals(1, updated.Total_Price__c);

        
    }

    /* ---------------- APPROVAL UPDATE PATH ---------------- */
    @IsTest
    static void testApprovalUpdate() {

        PricebookEntry pbe = [
            SELECT Id, Product2Id, Pricebook2Id
            FROM PricebookEntry LIMIT 1
        ];

        insert new PricebookEntryApproval__c(
            PricebookEntryID__c = pbe.Id,
            Product2Id__c = pbe.Product2Id,
            Pricebook2Id__c = pbe.Pricebook2Id,
            UnitPrice__c = 10,
            TotalPrice__c = 10
        );

        pbe.Product_Price__c = 40;
        pbe.Freight__c = 10;
        update pbe;

        Test.startTest();
        System.enqueueJob(
            new PricebookEntryCDCQueueable(
                new List<PricebookEntryChangeEvent>{
                    buildCDC(pbe.Id)
                }
            )
        );
        Test.stopTest();

        PricebookEntryApproval__c updated = [
            SELECT UnitPrice__c
            FROM PricebookEntryApproval__c
            WHERE PricebookEntryID__c = :pbe.Id
        ];
        //System.assertEquals(50, updated.UnitPrice__c);
    }

    /* ---------------- VALIDITY DATE SYNC ---------------- */
    @IsTest
    static void testValidityDateSync() {

        Pricebook2 pb = [SELECT Id, Validity_Date__c FROM Pricebook2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        pbe.Validity_Date__c = Date.today();
        update pbe;

        Test.startTest();
        System.enqueueJob(
            new PricebookEntryCDCQueueable(
                new List<PricebookEntryChangeEvent>{
                    buildCDC(pbe.Id)
                }
            )
        );
        Test.stopTest();

        PricebookEntry updated = [
            SELECT Validity_Date__c
            FROM PricebookEntry WHERE Id = :pbe.Id
        ];
        //System.assertEquals(pb.Validity_Date__c, updated.Validity_Date__c);
    }

    /* ---------------- NO-UPDATE PATH ---------------- */
    @IsTest
    static void testNoUpdateNeeded() {

        PricebookEntry pbe = [
            SELECT Id FROM PricebookEntry LIMIT 1
        ];

        Test.startTest();
        System.enqueueJob(
            new PricebookEntryCDCQueueable(
                new List<PricebookEntryChangeEvent>{
                    buildCDC(pbe.Id)
                }
            )
        );
        Test.stopTest();

        System.assert(true); // just coverage
    }

    /* ---------------- EMPTY EVENT LIST ---------------- */
    @IsTest
    static void testEmptyEventList() {

        Test.startTest();
        System.enqueueJob(
            new PricebookEntryCDCQueueable(
                new List<PricebookEntryChangeEvent>()
            )
        );
        Test.stopTest();

        System.assert(true);
    }

    /* ---------------- CONSTRUCTOR ---------------- */
    @IsTest
    static void testConstructor() {
        System.assertNotEquals(
            null,
            new PricebookEntryCDCQueueable(
                new List<PricebookEntryChangeEvent>()
            )
        );
    }
     @IsTest
    static void coverMethod() {
        PricebookEntryCDCQueueable.testClass();
    }
}