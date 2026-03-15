@IsTest
public class MaterialBlockLineItemServiceTest {
    
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
    
    /* =========================================================
* DIRECT BLOCK — UPDATE Sales Contract Line Item
* ========================================================= */
    @IsTest
static void testDirectBlockedProduct_UpdateContractLine() {

    Contract con = [
        SELECT Id, ContractApprovalStatus__c
        FROM Contract
        LIMIT 1
    ];

    con.ContractApprovalStatus__c = 'Draft';
    update con;

    // Step 1: insert NON-blocked product
    Product2 prod = new Product2(
        Name = 'TEMP-PROD',
        ProductCode = 'MAT-TEMP',
        IsActive = true,
        Material_Blocked__c = 'No',
        Family = 'Iron Ore'
    );
    insert prod;

    Sales_Contract_Line_Item__c scl = new Sales_Contract_Line_Item__c(
        Contract__c = con.Id,
        Product__c = prod.Id,
        Quantity__c = 5,
        List_Price__c = 100
    );
    insert scl;

    // Step 2: block product AFTER insert
    prod.Material_Blocked__c = 'Yes';
    update prod;

    Test.startTest();
    try {
        scl.Quantity__c = 10;
        update scl;
        System.assert(false, 'Update should be blocked');
    } catch (DmlException e) {
        System.assert(
            e.getMessage().toLowerCase().contains('blocked'),
            e.getMessage()
        );
    }
    Test.stopTest();
}

    
    /* =========================================================
* DOCUMENT FREEZE — UPDATE Contract Line when ANY blocked exists
* ========================================================= */
 @IsTest
static void testDocumentFreeze_UpdateContractLine() {

    Contract con = [
        SELECT Id, ContractApprovalStatus__c
        FROM Contract
        LIMIT 1
    ];

    con.ContractApprovalStatus__c = 'Draft';
    update con;

    Product2 prod1 = new Product2(
        Name = 'P1',
        ProductCode = 'MAT-P1',
        IsActive = true,
        Material_Blocked__c = 'No',
        Family = 'Iron Ore'
    );
    insert prod1;

    Product2 prod2 = new Product2(
        Name = 'P2',
        ProductCode = 'MAT-P2',
        IsActive = true,
        Material_Blocked__c = 'No',
        Family = 'Iron Ore'
    );
    insert prod2;

    Sales_Contract_Line_Item__c line1 = new Sales_Contract_Line_Item__c(
        Contract__c = con.Id,
        Product__c = prod1.Id,
        Quantity__c = 1,
        List_Price__c = 100
    );
    insert line1;

    Sales_Contract_Line_Item__c line2 = new Sales_Contract_Line_Item__c(
        Contract__c = con.Id,
        Product__c = prod2.Id,
        Quantity__c = 2,
        List_Price__c = 200
    );
    insert line2;

    // Freeze document
    prod1.Material_Blocked__c = 'Yes';
    update prod1;

    Test.startTest();
    try {
        line2.Quantity__c = 5;
        update line2;
        System.assert(false);
    } catch (DmlException e) {
        System.assert(
            e.getMessage().toLowerCase().contains('frozen') ||
            e.getMessage().toLowerCase().contains('blocked'),
            e.getMessage()
        );
    }
    Test.stopTest();
}

    /* =========================================================
* DIRECT BLOCK — DELETE Order Item
* ========================================================= */
    @IsTest
    static void testDirectBlockedProduct_DeleteOrderItem() {
        
        Order ord = [
            SELECT Id
            FROM Order
            LIMIT 1
        ];
        
        // Step 1: non-blocked product
        Product2 prod = new Product2(
            Name = 'TEMP-PROD',
            ProductCode = 'MAT-TEMP',
            IsActive = true,
            Material_Blocked__c = 'No',
            Family = 'Iron Ore'
        );
        insert prod;
        
        Id stdPbId = Test.getStandardPricebookId();
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;
        
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );
        insert oi;
        
        // Step 2: block AFTER insert
        prod.Material_Blocked__c = 'Yes';
        update prod;
        
        Test.startTest();
        try {
            delete oi;
            System.assert(false, 'Delete should be blocked');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().toLowerCase().contains('blocked'),
                'Expected blocked delete error, got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }
    
    /* =========================================================
* INSERT SHOULD NEVER BE BLOCKED
* ========================================================= */
    @IsTest
static void testInsertIsNeverBlocked() {

    Contract con = [
        SELECT Id, ContractApprovalStatus__c
        FROM Contract
        LIMIT 1
    ];

    con.ContractApprovalStatus__c = 'Draft';
    update con;

    Product2 prod = new Product2(
        Name = 'OK-PROD',
        ProductCode = 'MAT-OK',
        IsActive = true,
        Material_Blocked__c = 'No',
        Family = 'Iron Ore'
    );
    insert prod;

    Test.startTest();
    Sales_Contract_Line_Item__c scl = new Sales_Contract_Line_Item__c(
        Contract__c = con.Id,
        Product__c = prod.Id,
        Quantity__c = 1,
        List_Price__c = 100
    );
    insert scl;
    Test.stopTest();

    System.assertNotEquals(null, scl.Id);
}

}