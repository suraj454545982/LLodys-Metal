@IsTest
public class SalesOrderTriggerHandlerTest {
    
    // =====================================================
    // SHARED IDS (TEST)
    // =====================================================
    private static Id accId;
    private static Id oppId;
    private static Id prodId;
    private static Id poId;
    private static Id qId;
    
    // =====================================================
    // EXACT TEST SETUP (COPIED — NO CHANGES)
    // =====================================================
    @TestSetup
    static void setupOnce() {
        
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);
        
        Account acc = new Account(
            Name = 'Test Account',
            Phone = '9999999999',
            Organization_Code__c = '2000',
            Distribution_Channel__c = '20',
            Division__c = '0',
            SAP_Customer_Code__c = 'SAP1022'
        );
        insert acc;
        accId = acc.Id;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            Category__c = 'Iron Ore',
            Plant_and_Shipping_Point__c = '2060',
            PO_Received__c = 'Yes'
        );
        insert opp;
        oppId = opp.Id;
        
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            Plant__c = '2060',
            Family = 'Iron Ore'
        );
        insert prod;
        prodId = prod.Id;
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            ApprovalStatus_c__c = 'Approved',
            Validity_Date__c = Date.today() + 30
        );
        insert pbe;
        
        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 100,
            UnitPrice = 100
        );
        
        opp.StageName = 'Quotation';
        update opp;
        
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = oppId,
            BillingName = 'Billing Name',
            Additional_Terms_and_Condition__c = 'this is sample text'
        );
        insert q;
        qId = q.Id;
        
        insert new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Product2Id = prod.Id,
            Quantity = 100,
            UnitPrice = 100
        );
        
        q.Status = 'Accepted';
        update q;
        
        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'PO-001',
            Opportunity__c = opp.Id,
            Quote__c = q.Id,
            PO_Approval_Status__c = 'Draft',
            PO_Date__c = Date.today()
        );
        insert po;
        poId = po.Id;
        
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
        
        po.PO_Approval_Status__c = 'Approved';
        update po;
    }
    
    // =====================================================
    // HELPER — CREATE APPROVED CONTRACT
    // =====================================================
    private static Contract createApprovedContract() {
        
        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            WHERE PO_Received__c = 'Yes'
            LIMIT 1
        ];
        
        Quote q = [
            SELECT Id
            FROM Quote
            WHERE OpportunityId = :opp.Id
            LIMIT 1
        ];
        
        Purchase_Order__c po = [
            SELECT Id
            FROM Purchase_Order__c
            WHERE Opportunity__c = :opp.Id
            AND Quote__c = :q.Id
            LIMIT 1
        ];
        
        Contract con = new Contract(
            Opportunity__c = opp.Id,
            Purchase_Order_Name__c = po.Id,
            Contract_TypeNew__c = 'ZZSF',
            Quote_Name__c = q.Id,
            ContractApprovalStatus__c = 'Draft'
        );
        insert con;
        
        insert new Sales_Contract_Line_Item__c(
            Contract__c = con.Id,
            Product__c = prodId,
            Quantity__c = 100,
            List_Price__c = 100,
            Product_Number__c = 'P-100'
        );
        
        con.ContractApprovalStatus__c = 'Approved';
        update con;
        
        return con;
    }
    
    // =====================================================
    // TEST — ORDER CREATION SUCCESS
    // =====================================================
    @IsTest
    static void testOrderCreationSuccess() {
        
        Contract con = createApprovedContract();
        
        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            WHERE Id = :con.Opportunity__c
        ];
        
        Test.startTest();
        
        Order ord = new Order(
            Name = 'Test Order',
            EffectiveDate = Date.today(),
            Status = 'Draft',
            OpportunityId = opp.Id,
            ContractId = con.Id,
            Delivery_Schedule_Line_Number__c = 50
        );
        
        insert ord;
        
        Test.stopTest();
        
        List<OrderItem> items = [
            SELECT Id
            FROM OrderItem
            WHERE OrderId = :ord.Id
        ];
        
        System.assert(
            items.size() > 0,
            'OrderItems should be created'
        );
    }
    
    // =====================================================
    // TEST — APPROVAL VALIDATION
    // =====================================================
    @IsTest
    static void testValidateApprovalQuantities() {
        
        Contract con = createApprovedContract();
        
        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            WHERE Id = :con.Opportunity__c
        ];
        
        Order ord = new Order(
            Name = 'Approval Test',
            EffectiveDate = Date.today(),
			Sales_Order_Approval__c = 'Draft',
            OpportunityId = opp.Id,
            ContractId = con.Id,
            Delivery_Schedule_Line_Number__c = 50
        );
        insert ord;
        
        Test.startTest();
        
        ord.Sales_Order_Approval__c = 'Approved';
        update ord;
        
        
        
        Order refreshed = [
            SELECT Sales_Order_Approval__c
            FROM Order
            WHERE Id = :ord.Id
        ];
        
        Test.stopTest();
        System.assertEquals(
            'Approved',
            refreshed.Sales_Order_Approval__c
        );
    }
    
}