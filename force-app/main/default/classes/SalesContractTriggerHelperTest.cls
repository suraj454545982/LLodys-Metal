@IsTest
public class SalesContractTriggerHelperTest {

    /* =====================================================
       HTTP MOCK FOR getAccessToken()
    ======================================================*/
    private class TokenMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token":"TEST_TOKEN_123"}');
            return res;
        }
    }

    /* =====================================================
       TEST: processSAPSync + fetchSAPInsertIds
       Covers:
       - fetchSAPInsertIds
       - processSAPSync
    ======================================================*/
    @IsTest
    static void testProcessSAPSync_InsertFlow() {
        
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(
            Id = stdPbId,
            IsActive = true,
            Validity_Date__c = Date.today().addDays(10)
        );
        
        // Account (required in most orgs)
        Account acc = new Account(
            Name = 'Test Account',
            Phone = '9999999999',
            Organization_Code__c = '2000',
            Distribution_Channel__c = '20',
            Division__c = '0',
            SAP_Customer_Code__c = 'SAP1022'
        );
        insert acc;

        // Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Quotation',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            Plant_and_Shipping_Point__c = '2060',
            Category__c = 'Iron Ore',     
            Quote_status__c = 'Accepted'
        );
        insert opp;
        
        System.debug('Opp Id '+opp.Id);
        
        // Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            Plant__c = '2060',
            Family = 'Iron Ore'
        );
        insert prod;

        // Pricebook Entry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = prod.Id,
            UnitPrice    = 100,
            IsActive     = true,
            Validity_Date__c = Date.today().addDays(10),
            ApprovalStatus_c__c = 'Approved'
        );
        insert pbe;

        // Required OLI (org validation)
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );
        insert oli;
		
        // Quote
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Status = 'Draft',
            BillingName = 'billing name',
            Additional_Terms_and_Condition__c = 'this is sample text'
        );
        insert q;
        /*
        System.debug('======================Quote Insert======================');
        System.debug('Quote Id'+q.Id);
        System.debug('Quote Additional'+q.Additional_Terms_and_Condition__c);
        System.debug('Quote Billing '+q.BillingName);
        System.debug('Quote Status'+q.Status);
        System.debug('Quote Opportunity Id'+ q.OpportunityId);
        */
        
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );
        insert qli;
        
        Quote qUpdate = new Quote(Id = q.Id, Status = 'Accepted', OpportunityId = opp.Id);
        update qUpdate;
        /*
        System.debug('======================Quote Update======================');
        System.debug('Quote Id'+qUpdate.Id);
        System.debug('Quote Billing '+qUpdate.BillingName);
        System.debug('Quote Additional'+qUpdate.Additional_Terms_and_Condition__c);
        System.debug('Quote Status'+qUpdate.Status);
        System.debug('Quote Opportunity Id'+ qUpdate.OpportunityId);
		*/
		
        Opportunity oppUpdate = new Opportunity(id = opp.Id, PO_Received__c = 'Yes',StageName = 'Closed Won');
        update oppUpdate; 
        
        
        // Purchase Order
        Purchase_Order__c po = new Purchase_Order__c(
            Name = '123',
            PO_Date__c = Date.today().addDays(-10),
            Quote__c = qUpdate.Id,
            Opportunity__c = oppUpdate.Id,
            PO_Approval_Status__c = 'Approved'
        );
        insert po; 
        
        
       

        // --- Create Contract (NEW STATE) ---
        Contract con = new Contract(
            Contract_TypeNew__c = 'ZZSF',
            Purchase_Order_Name__c = po.Id,
            Opportunity__c = opp.Id
            
        );
        insert con; 

        // --- OLD STATE (Trigger.oldMap simulation) ---
        Contract oldCon = new Contract(
            Id = con.Id,
            Trigger_SAP_Insert__c = false,
            ContractApprovalStatus__c = 'Approval'
        );

        Map<Id, Contract> oldMap = new Map<Id, Contract>{
            con.Id => oldCon
        };

        // --- Call method ---
        Test.startTest();
        SalesContractTriggerHelper.processSAPSync(
            new List<Contract>{ con },
            oldMap
        );
        Test.stopTest();
    }

    /* =====================================================
       TEST: getAccessToken
    ======================================================*/
    @IsTest
    static void testGetAccessToken() {

        // Register mock
        Test.setMock(HttpCalloutMock.class, new TokenMock());

        Test.startTest();
        SalesContractTriggerHelper.getAccessToken();
        Test.stopTest();
    }

    /* =====================================================
       TEST: createApiLog
    ======================================================*/
    @IsTest
    static void testCreateApiLog() {

        List<SAPResponseWrapper> wrappers = new List<SAPResponseWrapper>();

        Test.startTest();
        SalesContractTriggerHelper.createApiLog(
            wrappers,
            '{"sample":"request"}',
            'SUCCESS',
            null,
            'POST',
            'CONTRACT',
            200,
            UserInfo.getUserId()
        );
        Test.stopTest();
    }

    /* =====================================================
       TEST: buildHeaderTexts
    ======================================================*/
    @IsTest
    static void testBuildHeaderTexts() {

        // Fake Contract record with dynamic fields
        Contract con = new Contract();
        con.put('Text_Header__c', 'Z247;Z248');
        con.put('Text_Z247__c', 'Header Text 247');
        con.put('Text_Z247__c', 'Header Text -247 ');
        con.put('Text_Z247__c', 'Header Text -24');
        //con.put('Text_Z248__c', 'Header Text 248');
        con.put('Text_Header__c', 'Z247-Test Header');

        Test.startTest();
        SalesContractTriggerHelper.buildHeaderTexts(con);
        Test.stopTest();
    }

    /* =====================================================
       TEST: buildHeaderTexts – EMPTY INPUT
       Covers early return path
    ======================================================*/
    @IsTest
    static void testBuildHeaderTexts_Empty() {

        Contract con = new Contract();
        con.put('Text_Header__c', null);

        Test.startTest();
        SalesContractTriggerHelper.buildHeaderTexts(con);
        Test.stopTest();
    }
}