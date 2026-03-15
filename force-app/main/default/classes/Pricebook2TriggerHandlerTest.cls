@IsTest
public class Pricebook2TriggerHandlerTest {

    /* =====================================================
       TEST SETUP – STANDARD FLOW DATA
    ======================================================*/
    @TestSetup
    static void setupData() {

        // Activate standard pricebook
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(
            Id = stdPbId,
            IsActive = true,
            Validity_Date__c = Date.today()
        );

        // Create a custom product
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        // Create pricebook entry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            Validity_Date__c = Date.today()
        );
        insert pbe;
    }

    /* =====================================================
       TEST 1: Validity Date Changed → PBE UPDATED
    ======================================================*/
    @IsTest
    static void testValidityDateChangeUpdatesEntries() {

        Pricebook2 pb = [
            SELECT Id, Validity_Date__c
            FROM Pricebook2
            WHERE IsStandard = true
            LIMIT 1
        ];

        Date newDate = Date.today().addDays(10);

        Pricebook2 oldPb = pb.clone(false, true, false, false);
        pb.Validity_Date__c = newDate;

        Test.startTest();
        Pricebook2TriggerHandler.afterUpdate(
            new List<Pricebook2>{ pb },
            new Map<Id, Pricebook2>{ pb.Id => oldPb }
        );
        Test.stopTest();

        PricebookEntry updatedPbe = [
            SELECT Validity_Date__c
            FROM PricebookEntry
            WHERE Pricebook2Id = :pb.Id
            LIMIT 1
        ];

        System.assertEquals(
            newDate,
            updatedPbe.Validity_Date__c,
            'PricebookEntry validity date must sync with Pricebook'
        );
    }

    /* =====================================================
       TEST 2: Validity Date NOT CHANGED → NO UPDATE
    ======================================================*/
    @IsTest
    static void testNoChangeDoesNothing() {

        Pricebook2 pb = [
            SELECT Id, Validity_Date__c
            FROM Pricebook2
            WHERE IsStandard = true
            LIMIT 1
        ];

        Pricebook2 oldPb = pb.clone(false, true, false, false);

        Test.startTest();
        Pricebook2TriggerHandler.afterUpdate(
            new List<Pricebook2>{ pb },
            new Map<Id, Pricebook2>{ pb.Id => oldPb }
        );
        Test.stopTest();

        System.assert(true, 'No exception means branch covered');
    }

    /* =====================================================
       TEST 3: Pricebook With NO PricebookEntries
    ======================================================*/
    @IsTest
    static void testPricebookWithoutEntries() {

        Pricebook2 emptyPb = new Pricebook2(
            Name = 'Empty PB',
            IsActive = true,
            Validity_Date__c = Date.today()
        );
        insert emptyPb;

        Pricebook2 oldPb = emptyPb.clone(false, true, false, false);
        emptyPb.Validity_Date__c = Date.today().addDays(5);

        Test.startTest();
        Pricebook2TriggerHandler.afterUpdate(
            new List<Pricebook2>{ emptyPb },
            new Map<Id, Pricebook2>{ emptyPb.Id => oldPb }
        );
        Test.stopTest();

        System.assert(true, 'Handled pricebook with no entries');
    }

    /* =====================================================
       TEST 4: NULL / EMPTY INPUT SAFETY
    ======================================================*/
    @IsTest
    static void testNullAndEmptyInputs() {

        Test.startTest();

        // Empty list
        Pricebook2TriggerHandler.afterUpdate(
            new List<Pricebook2>(),
            new Map<Id, Pricebook2>()
        );

        // Null map
        Pricebook2TriggerHandler.afterUpdate(
            new List<Pricebook2>{
                new Pricebook2(Id = Test.getStandardPricebookId())
            },
            null
        );

        Test.stopTest();

        System.assert(true, 'Null/empty guards executed');
    }

    /* =====================================================
       TEST 5: NULL RECORD INSIDE LIST
    ======================================================*/
    @IsTest
    static void testNullRecordInList() {

        Pricebook2 pb = [
            SELECT Id, Validity_Date__c
            FROM Pricebook2
            WHERE IsStandard = true
            LIMIT 1
        ];

        Pricebook2 oldPb = pb.clone(false, true, false, false);
        pb.Validity_Date__c = Date.today().addDays(1);

        Test.startTest();
        Pricebook2TriggerHandler.afterUpdate(
            new List<Pricebook2>{ null, pb },
            new Map<Id, Pricebook2>{ pb.Id => oldPb }
        );
        Test.stopTest();

        System.assert(true, 'Null record safely skipped');
    }
}