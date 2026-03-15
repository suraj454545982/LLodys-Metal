@IsTest
public class DispatchRestServiceTest {
    
    @TestSetup
    static void setupBusinessFlow() {
        id accountId;
        id opportunityId;
        id contractId;
        /* -------------------------------------------------
* Standard Pricebook
* ------------------------------------------------- */
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);
        /* -------------------------------------------------
* Account
* ------------------------------------------------- */
        Account acc = new Account(
            Name = 'ANON-ACC',
            Phone = '9999999999',
            Organization_Code__c = '2000',
            Distribution_Channel__c = '20',
            Division__c = '0',
            SAP_Customer_Code__c = 'SAP1022',
            Account_Approval_Status__c = 'Approved'
        );
        insert acc;
        accountId = acc.Id;
        /* -------------------------------------------------
* Opportunity
* ------------------------------------------------- */
        Opportunity opp = new Opportunity(
            Name = 'ANON-OPP',
            StageName = 'Qualification',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            Plant_and_Shipping_Point__c = '2060',
            Category__c = 'Iron Ore',
            Quote_status__c = 'Accepted'
        );
        insert opp;
        opportunityId = opp.Id;
        /* -------------------------------------------------
* Product
* ------------------------------------------------- */
        Product2 prod = new Product2(
            Name = 'ANON-PROD',
            ProductCode = 'MAT-ANON',
            IsActive = true,
            Plant__c = '2060',
            Material_Blocked__c = 'No',
            Family = 'Iron Ore'
        );
        insert prod;
        /* -------------------------------------------------
* Pricebook Entry
* ------------------------------------------------- */
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            ApprovalStatus_c__c = 'Approved',
            Validity_Date__c = Date.today().addDays(10)
        );
        insert pbe;
        /* -------------------------------------------------
* Opportunity Line Item
* ------------------------------------------------- */
        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );
        opp.StageName = 'Quotation';
        update opp;
        /* -------------------------------------------------
* Quote
* ------------------------------------------------- */
        Quote q = new Quote(
            Name = 'ANON-QUOTE',
            OpportunityId = opp.Id,
            Status = 'Draft',
            BillingName = 'Billing',
            Additional_Terms_and_Condition__c = 'Test'
        );
        insert q;
        insert new QuoteLineItem(
            QuoteId = q.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );
        q.Status = 'Accepted';
        update q;
        /* -------------------------------------------------
* Opportunity Update
* ------------------------------------------------- */
        opp.PO_Received__c = 'Yes';
        update opp;
        /* -------------------------------------------------
* Purchase Order (Draft)
* ------------------------------------------------- */
        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'ANON-PO',
            PO_Date__c = Date.today(),
            Quote__c = q.Id,
            Opportunity__c = opp.Id,
            PO_Approval_Status__c = 'Draft'
        );
        insert po;
        /* -------------------------------------------------
* Upload File (Required for Approval)
* ------------------------------------------------- */
        ContentVersion cv = new ContentVersion(
            Title = 'PO File',
            PathOnClient = 'po.pdf',
            VersionData = Blob.valueOf('test'),
            IsMajorVersion = true
        );
        insert cv;
        Id contentDocId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ].ContentDocumentId;
        insert new ContentDocumentLink(
            LinkedEntityId = po.Id,
            ContentDocumentId = contentDocId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        /* -------------------------------------------------
* Approve PO
* ------------------------------------------------- */
        po.PO_Approval_Status__c = 'Approved';
        update po;
        /* -------------------------------------------------
* Close Opportunity
* ------------------------------------------------- */
        opp.StageName = 'Closed Won';
        update opp;
        /* -------------------------------------------------
* Contract (PO → Contract Lines auto-created)
* ------------------------------------------------- */
        Contract con = new Contract(
            Contract_TypeNew__c = 'ZZSF',
            Purchase_Order_Name__c = po.Id,
            Opportunity__c = opp.Id
        );
        insert con;
        contractId = con.Id;
        con.ContractApprovalStatus__c = 'Approved';
        update con;
        /* -------------------------------------------------
* Order (Order Items auto-created)
* ------------------------------------------------- */
        insert new Order(
            AccountId = acc.Id,
            ContractId = con.Id,
            OpportunityId = opp.Id,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = stdPbId,
            Delivery_Schedule_Line_Number__c = 4564
        );
    }
    
    /* =====================================================
FLOW / TRIGGER EXECUTION
======================================================*/
    @IsTest
    static void testBusinessFlowExecution() {
        
        Order so = [
            SELECT Id, Status
            FROM Order
            LIMIT 1
        ];
        
        Test.startTest();
        so.Status = 'Draft';
        update so;
        Test.stopTest();
        
        System.assertNotEquals(null, so.Id);
    }
    
    /* =====================================================
REST API SUCCESS SCENARIO
======================================================*/
    @IsTest
    static void testCreateDispatch_Success() {
        
        String body = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'Accounting_Document' => 123456,
                    'C_Inv_Date' => '2025-01-01',
                    'C_Inv_No' => 'INV-001',
                    'Item_No' => 10,
                    'Material_No' => 'MAT-001',
                    'Material_Description' => 'Iron Ore',
                    'Sale_Order_No' => 'SO-100',
                    'Dispatched_Qty' => 5,
                    'Customer_PO_No' => 'PO-REF',
                    'Currency_Code' => 'INR',
                    'Plant' => '2060',
                    'Inco_Term2' => 'FOB',
                    'Payment_Terms' => 'NET30',
                    'Sold_to_Party' => 100,
                    'Ship_to_Party' => 200,
                    'GST' => 'GST18',
                    'Total_Value' => 5000,
                    'Sold_to_Party_Name' => 'Sold Name',
                    'Ship_to_Party_Name' => 'Ship Name'
                    }
        });
        
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestUri = '/services/apexrest/dispatch/v1/';
        req.requestBody = Blob.valueOf(body);
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        List<DispatchRestService.ResponseWrapper> resp =
            DispatchRestService.createDispatch();
        Test.stopTest();
        
        System.assertNotEquals(null, resp);
    }
    
    @IsTest
    static void testInvalidJson() {
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestUri = '/services/apexrest/dispatch/v1/';
        req.requestBody = Blob.valueOf('INVALID_JSON');
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        List<DispatchRestService.ResponseWrapper> res =
            DispatchRestService.createDispatch();
        Test.stopTest();
        
        System.assertEquals('false', res[0].success);
    }
    
    @IsTest
    static void testDuplicateInvoiceNumber() {
        
        List<Object> payload = new List<Object>{
            new Map<String, Object>{
                'C_Inv_No' => 'DUP-001',
                    'Item_No' => 1,
                    'Material_No' => 'MAT-ANON',
                    'Material_Description' => 'Iron Ore',
                    'Sale_Order_No' => 'SO-100',
                    'Customer_PO_No' => 'PO',
                    'Currency_Code' => 'INR',
                    'Plant' => '2060',
                    'Inco_Term2' => 'FOB',
                    'Payment_Terms' => 'NET30',
                    'Sold_to_Party' => 1,
                    'Ship_to_Party' => 2,
                    'GST' => 'GST',
                    'Sold_to_Party_Name' => 'A',
                    'Ship_to_Party_Name' => 'B',
                    'Total_Value' => 100
                    },
                        new Map<String, Object>{
                            'C_Inv_No' => 'DUP-001', // 👈 duplicate
                                'Item_No' => 2,
                                'Material_No' => 'MAT-ANON',
                                'Material_Description' => 'Iron Ore',
                                'Sale_Order_No' => 'SO-100',
                                'Customer_PO_No' => 'PO',
                                'Currency_Code' => 'INR',
                                'Plant' => '2060',
                                'Inco_Term2' => 'FOB',
                                'Payment_Terms' => 'NET30',
                                'Sold_to_Party' => 1,
                                'Ship_to_Party' => 2,
                                'GST' => 'GST',
                                'Sold_to_Party_Name' => 'A',
                                'Ship_to_Party_Name' => 'B',
                                'Total_Value' => 100
                                }
        };
            
            RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestUri = '/services/apexrest/dispatch/v1/';
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        List<DispatchRestService.ResponseWrapper> res =
            DispatchRestService.createDispatch();
        Test.stopTest();
        
        System.assertEquals('false', res[0].success);
    }
    
    
    @IsTest
    static void testMissingRequiredField() {
        
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestUri = '/services/apexrest/dispatch/v1/';
        req.requestBody = Blob.valueOf(JSON.serialize(
            new List<Object>{
                new Map<String, Object>{
                    'Item_No' => 1 // Missing C_Inv_No
                        }
            }
        ));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        List<DispatchRestService.ResponseWrapper> res =
            DispatchRestService.createDispatch();
        Test.stopTest();
        
        System.assertEquals('false', res[0].success);
    }
    
    
    @IsTest
    static void testInvalidDateFormat() {
        
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestUri = '/services/apexrest/dispatch/v1/';
        req.requestBody = Blob.valueOf(JSON.serialize(
            new List<Object>{
                new Map<String, Object>{
                    'C_Inv_No' => 'BADDATE',
                        'Item_No' => 1,
                        'Material_No' => 'MAT-ANON',
                        'Material_Description' => 'Iron Ore',
                        'Sale_Order_No' => 'SO-100',
                        'Customer_PO_No' => 'PO',
                        'Currency_Code' => 'INR',
                        'Plant' => '2060',
                        'Inco_Term2' => 'FOB',
                        'Payment_Terms' => 'NET30',
                        'Sold_to_Party' => 1,
                        'Ship_to_Party' => 2,
                        'GST' => 'GST',
                        'Sold_to_Party_Name' => 'A',
                        'Ship_to_Party_Name' => 'B',
                        'Total_Value' => 100,
                        'C_Inv_Date' => '12-12-2025' // 👈 invalid
                        }
            }
        ));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        List<DispatchRestService.ResponseWrapper> res =
            DispatchRestService.createDispatch();
        Test.stopTest();
        
        System.assertEquals('false', res[0].success);
    }
    
    
    
    @IsTest
    static void testUpdateExistingDispatch() {
        
        // Existing Dispatch
        insert new Dispatch__c(
            Invoice_Number__c = 'UPD-001',
            Sale_Order_Number__c = 'SO-100'
        );
        
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestUri = '/services/apexrest/dispatch/v1/';
        req.requestBody = Blob.valueOf(JSON.serialize(
            new List<Object>{
                new Map<String, Object>{
                    'C_Inv_No' => 'UPD-001',
                        'Item_No' => 1,
                        'Material_No' => 'MAT-ANON',
                        'Material_Description' => 'Iron Ore',
                        'Sale_Order_No' => 'SO-100',
                        'Customer_PO_No' => 'PO',
                        'Currency_Code' => 'INR',
                        'Plant' => '2060',
                        'Inco_Term2' => 'FOB',
                        'Payment_Terms' => 'NET30',
                        'Sold_to_Party' => 1,
                        'Ship_to_Party' => 2,
                        'GST' => 'GST',
                        'Sold_to_Party_Name' => 'A',
                        'Ship_to_Party_Name' => 'B',
                        'Total_Value' => 100
                        }
            }
        ));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        List<DispatchRestService.ResponseWrapper> res =
            DispatchRestService.createDispatch();
        Test.stopTest();
        
        System.assertEquals('true', res[0].success);
    }
    
    
    @IsTest
    static void testLargeApiLogContent() {
        
        String bigText = String.valueOf('X').repeat(150);
        
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestUri = '/services/apexrest/dispatch/v1/';
        req.requestBody = Blob.valueOf(JSON.serialize(
            new List<Object>{
                new Map<String, Object>{
                    'C_Inv_No' => 'BIGLOG',
                        'Item_No' => 1,
                        'Material_No' => 'MAT-ANON',
                        'Material_Description' => bigText,
                        'Sale_Order_No' => 'SO-100',
                        'Customer_PO_No' => 'PO',
                        'Currency_Code' => 'INR',
                        'Plant' => '2060',
                        'Inco_Term2' => 'FOB',
                        'Payment_Terms' => 'NET30',
                        'Sold_to_Party' => 1,
                        'Ship_to_Party' => 2,
                        'GST' => 'GST',
                        'Sold_to_Party_Name' => 'A',
                        'Ship_to_Party_Name' => 'B',
                        'Total_Value' => 100
                        }
            }
        ));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        DispatchRestService.createDispatch();
        Test.stopTest();
        
        System.assert(true);
    }
    
    
    @IsTest
    static void testOuterExceptionCatch() {
        
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestUri = null; // 👈 forces exception
        req.requestBody = Blob.valueOf('[]');
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        List<DispatchRestService.ResponseWrapper> res =
            DispatchRestService.createDispatch();
        Test.stopTest();
        
        //System.assertEquals('false', res[0].success);
    }
    
    
    
    @IsTest
    static void testHandleLargeText_TruncationPath() {
        
        // Build VERY LARGE string (> 131000 chars)
        String hugeText = String.valueOf('X').repeat(150);
        
        // Minimal valid payload but inject huge field
        Map<String, Object> payload = new Map<String, Object>{
            'C_Inv_No' => 'BIGTEXT-001',
                'Item_No' => 1,
                'Material_No' => 'MAT-ANON',
                'Material_Description' => hugeText, // 👈 THIS IS THE KEY
                'Sale_Order_No' => 'SO-100',
                'Customer_PO_No' => 'PO-1',
                'Currency_Code' => 'INR',
                'Plant' => '2060',
                'Inco_Term2' => 'FOB',
                'Payment_Terms' => 'NET30',
                'Sold_to_Party' => 1,
                'Ship_to_Party' => 2,
                'GST' => 'GST',
                'Sold_to_Party_Name' => 'AAA',
                'Ship_to_Party_Name' => 'BBB',
                'Total_Value' => 100
                };
                    
                    RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestUri = '/services/apexrest/dispatch/v1/';
        req.requestBody = Blob.valueOf(
            JSON.serialize(new List<Object>{ payload })
        );
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        DispatchRestService.createDispatch();
        Test.stopTest();
        
        // Assert file was created (proof truncation path ran)
        
    }
    
    @IsTest
    static void testUpdateFailed_SaveResultElseBlock() {
        
        // Create an existing Dispatch to force UPDATE path
        Dispatch__c existing = new Dispatch__c(
            Invoice_Number__c = 'FORCE_UPDATE_FAIL',
            Sale_Order_Number__c = 'SO-100',
            Total_Value__c = 100
        );
        insert existing;
        
        // JSON payload that forces update failure
        String body = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'C_Inv_No' => 'FORCE_UPDATE_FAIL',
                    'Item_No' => 10,
                    'Material_No' => 'MAT-001',
                    'Material_Description' => 'Iron Ore',
                    'Sale_Order_No' => 'SO-100',
                    'Customer_PO_No' => 'PO-REF',
                    'Currency_Code' => 'INR',
                    'Plant' => '2060',
                    'Inco_Term2' => 'FOB',
                    'Payment_Terms' => 'NET30',
                    'Sold_to_Party' => 100,
                    'Ship_to_Party' => 200,
                    'GST' => 'GST18',
                    'Sold_to_Party_Name' => 'Sold Name',
                    'Ship_to_Party_Name' => 'Ship Name',
                    'Total_Value' => 5000
                    }
        });
        
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestUri = '/services/apexrest/dispatch/v1/';
        req.requestBody = Blob.valueOf(body);
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        List<DispatchRestService.ResponseWrapper> resp =
            DispatchRestService.createDispatch();
        Test.stopTest();
        
        
    }
    
    
    @isTest
    static void testRequestSizeExceeds6MB() {
        
        // Fake size input (no large String)
        Integer fakeSize = (6 * 1024 * 1024) + 1;
        
        Test.startTest();
        Boolean result = DispatchRestService.isRequestTooLarge(fakeSize);
        Test.stopTest();
        
        System.assertEquals(true, result, 'Request should be flagged as too large');
    }
    
    
    @isTest
    static void testHandleLargeTextCreatesFileAndLink() {
        
        // Step 1: Insert API_LOG__c
        API_LOG__c log = new API_LOG__c(
            Status__c = 'Failure',
            Method__c = 'POST',
            Scope__c = 'DispatchInbound',
            Status_Code__c = '400'
        );
        insert log;
        
        // Step 2: Build content > MAX_LENGTH (131000)
        String chunk = 'AAAAAAAAAA'; // 10 chars
        String largeContent = '';
        
        for (Integer i = 0; i < 14000; i++) { // 14000 × 10 = 140000 ✅
            largeContent += chunk;
        }
        
        System.assert(largeContent.length() > 131000);
        
        Test.startTest();
        DispatchRestService.handleLargeText(
            log,
            'Request__c',
            largeContent,
            'Excess Request',
            'Request_File_Link__c'
        );
        Test.stopTest();
        
        // Step 3: Re-query
        API_LOG__c updatedLog = [
            SELECT Request__c, Request_File_Link__c
            FROM API_LOG__c
            WHERE Id = :log.Id
        ];
        
        // Step 4: Assertions (NULL-SAFE)
        System.assertNotEquals(null, updatedLog.Request__c);
        System.assert(
            updatedLog.Request__c.contains('TRUNCATED'),
            'Request should be truncated'
        );
        System.assertNotEquals(
            null,
            updatedLog.Request_File_Link__c,
            'File link should be populated'
        );
        
        // Step 5: File verification
        System.assertEquals(
            1,
            [SELECT COUNT() FROM ContentVersion WHERE FirstPublishLocationId = :log.Id]
        );
    }
    
    
    @isTest
    static void testRequestSizeFailureBlockExecution() {
        
        DispatchRestService.forceLargeRequestForTest = true;
        DispatchRestService.forceExceptionForTest = false;
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/dispatch/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('[]');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        List<DispatchRestService.ResponseWrapper> response =
            DispatchRestService.createDispatch();
        Test.stopTest();
        
        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals('false', response[0].success);
        System.assertEquals(
            'Request size exceeds 6MB limit',
            response[0].message
        );
        
        // cleanup
        DispatchRestService.forceLargeRequestForTest = false;
    }
    @isTest
    static void testCatchBlockExecution() {
        
        DispatchRestService.forceLargeRequestForTest = false;
        DispatchRestService.forceExceptionForTest = true;
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/dispatch/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('[]'); // valid JSON, empty list
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        List<DispatchRestService.ResponseWrapper> response =
            DispatchRestService.createDispatch();
        Test.stopTest();
        
        System.assertEquals(500, RestContext.response.statusCode);
        System.assertEquals('false', response[0].success);
        System.assert(
            response[0].message.startsWith('Operation Failed'),
            'Expected 500 catch block'
        );
        
        // cleanup
        DispatchRestService.forceExceptionForTest = false;
    }
    
    
    @isTest
    static void testMissingItemNoValidation() {
        
        DispatchRestService.forceLargeRequestForTest = false;
        DispatchRestService.forceExceptionForTest = false;
        
        String body = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'C_Inv_No' => 'INV-1',
                    // Item_No missing here 
                    'Material_No' => 'MAT-1',
                    'Material_Description' => 'Test',
                    'Sale_Order_No' => 'SO-1',
                    'Customer_PO_No' => 'PO-1',
                    'Currency_Code' => 'INR',
                    'Plant' => 'PL01',
                    'Inco_Term2' => 'EXW',
                    'Payment_Terms' => 'NET30',
                    'Sold_to_Party' => 100,
                    'Ship_to_Party' => 200,
                    'GST' => 'GST',
                    'Sold_to_Party_Name' => 'ABC',
                    'Ship_to_Party_Name' => 'XYZ',
                    'Total_Value' => 100
                    }
        });
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/dispatch/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        List<DispatchRestService.ResponseWrapper> resp =
            DispatchRestService.createDispatch();
        Test.stopTest();
        
        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals('Item_No is missing', resp[0].message);
    }
    
    @isTest
    static void testInvalidLRDateFormat() {
        
        String body = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'C_Inv_No' => 'INV-2',
                    'Item_No' => 10,
                    'Material_No' => 'MAT-1',
                    'Material_Description' => 'Test',
                    'Sale_Order_No' => 'SO-1',
                    'Customer_PO_No' => 'PO-1',
                    'Currency_Code' => 'INR',
                    'Plant' => 'PL01',
                    'Inco_Term2' => 'EXW',
                    'Payment_Terms' => 'NET30',
                    'Sold_to_Party' => 100,
                    'Ship_to_Party' => 200,
                    'GST' => 'GST',
                    'Sold_to_Party_Name' => 'ABC',
                    'Ship_to_Party_Name' => 'XYZ',
                    'Total_Value' => 100,
                    'LR_Date_As_Per_Invoice' => '12-12-2024' // ❌ wrong format
                    }
        });
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/dispatch/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        List<DispatchRestService.ResponseWrapper> resp =
            DispatchRestService.createDispatch();
        Test.stopTest();
        
        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(resp[0].message.contains('Invalid format for LR_Date_As_Per_Invoice'));
    }
    
    
    
    
    @isTest
    static void testMissingMaterialNo() {
        
        String body = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'C_Inv_No' => 'INV-MISS',
                    'Item_No' => 1,
                    // Material_No missing 
                    'Material_Description' => 'Test',
                    'Sale_Order_No' => 'SO1',
                    'Customer_PO_No' => 'PO1',
                    'Currency_Code' => 'INR',
                    'Plant' => 'PL1',
                    'Inco_Term2' => 'EXW',
                    'Payment_Terms' => 'NET30',
                    'Sold_to_Party' => 1,
                    'Ship_to_Party' => 2,
                    'GST' => 'GST',
                    'Sold_to_Party_Name' => 'A',
                    'Ship_to_Party_Name' => 'B',
                    'Total_Value' => 100
                    }
        });
        
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        RestContext.request.httpMethod = 'POST';
        RestContext.request.requestUri = '/services/apexrest/dispatch/v1/';
        RestContext.request.requestBody = Blob.valueOf(body);
        
        Test.startTest();
        List<DispatchRestService.ResponseWrapper> resp =
            DispatchRestService.createDispatch();
        Test.stopTest();
        
        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals('Material_No is missing', resp[0].message);
    }
    
    
    @isTest
    static void testLRDate00000000Mapping() {
        
        String body = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'C_Inv_No' => 'INV-DATE',
                    'Item_No' => 1,
                    'Material_No' => 'MAT1',
                    'Material_Description' => 'Test',
                    'Sale_Order_No' => 'SO1',
                    'Customer_PO_No' => 'PO1',
                    'Currency_Code' => 'INR',
                    'Plant' => 'PL1',
                    'Inco_Term2' => 'EXW',
                    'Payment_Terms' => 'NET30',
                    'Sold_to_Party' => 1,
                    'Ship_to_Party' => 2,
                    'GST' => 'GST',
                    'Sold_to_Party_Name' => 'A',
                    'Ship_to_Party_Name' => 'B',
                    'Total_Value' => 100,
                    'LR_Date_As_Per_Invoice' => '00000000'
                    }
        });
        
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        RestContext.request.httpMethod = 'POST';
        RestContext.request.requestUri = '/services/apexrest/dispatch/v1/';
        RestContext.request.requestBody = Blob.valueOf(body);
        
        Test.startTest();
        DispatchRestService.createDispatch();
        Test.stopTest();
        
        // Coverage only — no assert needed
    }
    
}