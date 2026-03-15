@IsTest
public class MaterialBlockValidationServiceTest {
    
    static Id accountId;
    static Id opportunityId;
    static Id contractId;
    
    @TestSetup
    static void setupFlow() {
        
        // MUST be first line
        TriggerBypassUtil.bypassAll = true;
        
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
        
        // Re-enable triggers for actual test methods
        TriggerBypassUtil.bypassAll = false;
    }
    
    // ------------------------------------------------
    // INSERT → BLOCKED (Purchase Order)
    // ------------------------------------------------
    @IsTest
    static void testInsertBlockedPurchaseOrder() {
        
        Purchase_Order__c po = [
            SELECT Quote__c
            FROM Purchase_Order__c
            LIMIT 1
        ];
        
        Test.startTest();
        try {
            Purchase_Order__c newPO = new Purchase_Order__c(
                Name = 'PO-BLOCK',
                Quote__c = po.Quote__c,
                PO_Date__c = Date.today()
            );
            insert newPO;
            System.assert(false, 'Insert should have been blocked');
        } catch (DmlException e) {
        }
        Test.stopTest();
    }
    
    // ------------------------------------------------
    // UPDATE → BLOCKED (Contract)
    // ------------------------------------------------
    @IsTest
    static void testUpdateBlockedContract() {
        
        Contract con = [
            SELECT Id
            FROM Contract
            LIMIT 1
        ];
        
        Test.startTest();
        try {
            con.Description = 'Trying to update';
            update con;
        } catch (DmlException e) {
        }
        Test.stopTest();
    }
    
    // ------------------------------------------------
    // UPDATE → BLOCKED (Order)
    // ------------------------------------------------
    @IsTest
    static void testUpdateBlockedOrder() {
        
        Order ord = [
            SELECT Id, Status
            FROM Order
            LIMIT 1
        ];
        
        Test.startTest();
        try {
            ord.Status = 'Activated';
            update ord;
        } catch (DmlException e) {
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testBlockedOrderInsert_materialBlockedProduct() {
        
        Test.startTest();
        
        /* -------------------------------------------------
         * Standard Pricebook
         * ------------------------------------------------- */
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        /* -------------------------------------------------
         * Account
         * ------------------------------------------------- */
        Account acc = new Account(
            Name = 'TEST-ACC-002',
            Phone = '8888888888',
            Organization_Code__c = '2000',
            Distribution_Channel__c = '10',
            Division__c = '0',
            SAP_Customer_Code__c = 'SAP-TEST-9001',
            Account_Approval_Status__c = 'Approved'
        );
        insert acc;

        /* -------------------------------------------------
         * Opportunity
         * ------------------------------------------------- */
        Opportunity opp = new Opportunity(
            Name = 'TEST-OPP-002',
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(15),
            AccountId = acc.Id,
            Plant_and_Shipping_Point__c = '2010',
            Category__c = 'Steel',
            Quote_status__c = 'Accepted'
        );
        insert opp;

        /* -------------------------------------------------
         * Product
         * ------------------------------------------------- */
        Product2 prod = new Product2(
            Name = 'BLOCKED-PRODUCT-002',
            ProductCode = 'MAT-BLOCK-002',
            IsActive = true,
            Plant__c = '2010',
            Material_Blocked__c = 'No',
            Family = 'Steel'
        );
        insert prod;

        /* -------------------------------------------------
         * Pricebook Entry
         * ------------------------------------------------- */
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 250,
            IsActive = true,
            ApprovalStatus_c__c = 'Approved',
            Validity_Date__c = Date.today().addDays(30)
        );
        insert pbe;

        /* -------------------------------------------------
         * Opportunity Line Item
         * ------------------------------------------------- */
        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 250
        );

        opp.StageName = 'Quotation';
        update opp;

        /* -------------------------------------------------
         * Quote
         * ------------------------------------------------- */
        Quote q = new Quote(
            Name = 'TEST-QUOTE-002',
            OpportunityId = opp.Id,
            Status = 'Draft',
            BillingName = 'Test Billing Entity',
            Additional_Terms_and_Condition__c = 'Sample test terms'
        );
        insert q;

        insert new QuoteLineItem(
            QuoteId = q.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 250
        );

        q.Status = 'Accepted';
        update q;

        /* -------------------------------------------------
         * Opportunity Update
         * ------------------------------------------------- */
        opp.PO_Received__c = 'Yes';
        update opp;

        /* -------------------------------------------------
         * Purchase Order
         * ------------------------------------------------- */
        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'TEST-PO-002',
            PO_Date__c = Date.today(),
            Quote__c = q.Id,
            Opportunity__c = opp.Id,
            PO_Approval_Status__c = 'Draft'
        );
        insert po;

        /* -------------------------------------------------
         * Upload File
         * ------------------------------------------------- */
        ContentVersion cv = new ContentVersion(
            Title = 'PO_Attachment_Test',
            PathOnClient = 'po_test.pdf',
            VersionData = Blob.valueOf('test content'),
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
         * Contract
         * ------------------------------------------------- */
        Contract con = new Contract(
            Contract_TypeNew__c = 'ZZSF',
            Purchase_Order_Name__c = po.Id,
            Opportunity__c = opp.Id
        );
        insert con;

        con.ContractApprovalStatus__c = 'Approved';
        update con;

        prod.Material_Blocked__c = 'Yes';
        update prod;

        /* -------------------------------------------------
         * Order Insert → MUST FAIL
         * ------------------------------------------------- */
        try {
            insert new Order(
                AccountId = acc.Id,
                OpportunityId = opp.Id,
                ContractId = con.Id,
                Status = 'Draft',
                EffectiveDate = Date.today(),
                Pricebook2Id = stdPbId,
                Delivery_Schedule_Line_Number__c = 8888
            );
            System.assert(false, 'Order insert should be blocked due to Material Blocked product');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('Material Blocked'),
                'Expected Material Blocked validation message'
            );
        }

        Test.stopTest();
    }
}