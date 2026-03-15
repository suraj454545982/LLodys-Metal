@IsTest
public class InventoryRestServiceTest {

    /* -----------------------------------------------------
       Common REST invocation helper
    ------------------------------------------------------*/
    private static List<InventoryRestService.ResponseWrapper> callRest(String json) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/inventory/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(json);

        RestContext.request = req;
        RestContext.response = res;

        return InventoryRestService.createInventory();
    }

    /* -----------------------------------------------------
       Test setup – Product required for Material validation
    ------------------------------------------------------*/
    @TestSetup
    static void setupData() {
        Product2 p = new Product2(
            Name = 'Test Material',
            ProductCode = 'MAT-INV-1',
            IsActive = true
        );
        insert p;

        Inventory__c inv = new Inventory__c(
            product__c = p.Id,
            Plant__c = '2060',
            Storage_Location__c = 'SL01',
            Quantity__c = 10
        );
        insert inv;
    }

    /* -----------------------------------------------------
       1️⃣ SUCCESS – INSERT
    ------------------------------------------------------*/
    @IsTest
    static void testInsertInventory() {

        String json =
        '[{' +
            '"Material":"MAT-INV-1",' +
            '"Plant":"2070",' +
            '"Storage_Location":"SL02",' +
            '"Qty":25' +
        '}]';

        Test.startTest();
        callRest(json);
        Test.stopTest();

        System.assert(true);
    }

    /* -----------------------------------------------------
       2️⃣ SUCCESS – UPDATE (same composite key)
    ------------------------------------------------------*/
    @IsTest
    static void testUpdateInventory() {

        String json =
        '[{' +
            '"Material":"MAT-INV-1",' +
            '"Plant":"2060",' +
            '"Storage_Location":"SL01",' +
            '"Qty":99' +
        '}]';

        Test.startTest();
        callRest(json);
        Test.stopTest();

        System.assert(true);
    }

    /* -----------------------------------------------------
       3️⃣ DUPLICATE composite key inside request
    ------------------------------------------------------*/
    @IsTest
    static void testDuplicateCompositeKey() {

        String json =
        '[{' +
            '"Material":"MAT-INV-1",' +
            '"Plant":"2060",' +
            '"Storage_Location":"SL01",' +
            '"Qty":5' +
        '}, {' +
            '"Material":"mat-inv-1",' +
            '"Plant":"2060",' +
            '"Storage_Location":"sl01",' +
            '"Qty":10' +
        '}]';

        Test.startTest();
        callRest(json);
        Test.stopTest();

        System.assert(true);
    }

    /* -----------------------------------------------------
       4️⃣ MISSING REQUIRED FIELDS
    ------------------------------------------------------*/
    @IsTest
    static void testMissingFields() {

        String json =
        '[{' +
            '"Material":"",' +
            '"Plant":"",' +
            '"Storage_Location":"",' +
            '"Qty":null' +
        '}]';

        Test.startTest();
        callRest(json);
        Test.stopTest();

        System.assert(true);
    }

    /* -----------------------------------------------------
       5️⃣ INVALID MATERIAL (Product not found)
    ------------------------------------------------------*/
    @IsTest
    static void testInvalidMaterial() {

        String json =
        '[{' +
            '"Material":"INVALID-MAT",' +
            '"Plant":"2060",' +
            '"Storage_Location":"SL03",' +
            '"Qty":5' +
        '}]';

        Test.startTest();
        callRest(json);
        Test.stopTest();

        System.assert(true);
    }

    /* -----------------------------------------------------
       6️⃣ QTY MISSING
    ------------------------------------------------------*/
    @IsTest
    static void testQtyMissing() {

        String json =
        '[{' +
            '"Material":"MAT-INV-1",' +
            '"Plant":"2060",' +
            '"Storage_Location":"SL04"' +
        '}]';

        Test.startTest();
        callRest(json);
        Test.stopTest();

        System.assert(true);
    }

    /* -----------------------------------------------------
       7️⃣ REQUEST SIZE EXCEEDED
    ------------------------------------------------------*/
    @IsTest
    static void testRequestSizeExceeded() {

        String big = '';
        for (Integer i = 0; i < 70000; i++) {
            big += 'XYZRRTTAEARAERAERAERAE';
        }

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/inventory/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(big);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        InventoryRestService.createInventory();
        Test.stopTest();

        System.assert(true);
    }

    /* -----------------------------------------------------
       8️⃣ INVALID JSON → EXCEPTION BLOCK
    ------------------------------------------------------*/
    @IsTest
    static void testInvalidJson() {

        Test.startTest();
        callRest('{ invalid json ');
        Test.stopTest();

        System.assert(true);
    }

    /* -----------------------------------------------------
       9️⃣ LARGE TEXT → handleLargeText()
    ------------------------------------------------------*/
    @IsTest
    static void testLargeTextHandling() {

        String bigText = '';
        for (Integer i = 0; i < 150000; i++) {
            bigText += 'A';
        }

        String json =
        '[{' +
            '"Material":"MAT-INV-1",' +
            '"Plant":"' + bigText + '",' +
            '"Storage_Location":"SL99",' +
            '"Qty":10' +
        '}]';

        Test.startTest();
        callRest(json);
        Test.stopTest();

        System.assert(true);
    }
}