@IsTest
public class SalesContractTriggerHandlerTest {
    
    
    private static Contract createContract(
        Id oppId,
        Id poId,
        Id quoteId
    ) {
        
        System.debug(':::ALL IDS:::'+oppId +' '+poId +' '+quoteId);
        Contract con = new Contract(
            Opportunity__c = oppId,
            Purchase_Order_Name__c = poId,
            Contract_TypeNew__c = 'ZZSF',
            Quote_Name__c = quoteId
        );
        insert con;
        return con;
    }
    
    private static Sales_Contract_Line_Item__c getContractLineItem(Id contractId) {
        return [
            SELECT Id, Quantity__c
            FROM Sales_Contract_Line_Item__c
            WHERE Contract__c = :contractId
            LIMIT 1
        ];
    }
    
    // =====================================================
    // SHARED IDS (USED BY ALL TEST METHODS)
    // =====================================================
    private static Id accId;
    private static Id oppId;
    private static Id prodId;
    private static Id poId;
    private static Id qId;
    
    // =====================================================
    // TEST SETUP – RUNS ONLY ONCE
    // =====================================================
    @TestSetup
    static void setupOnce() {

        
        // -------------------------------
        // Standard Pricebook
        // -------------------------------
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);
        
        // -------------------------------
        // Account
        // -------------------------------
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
        
        // -------------------------------
        // Opportunity
        // -------------------------------
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
        
        // -------------------------------
        // Product
        // -------------------------------
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            Plant__c = '2060',
            Family = 'Iron Ore'
        );
        insert prod;
        prodId = prod.Id;
        
        // -------------------------------
        // Pricebook Entry
        // -------------------------------
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            ApprovalStatus_c__c = 'Approved',
            Validity_Date__c = date.today()+30
        );
        insert pbe;
        
        /*Pricebook2 pb = [SELECT Id,Validity_Date__c,Name FROM Pricebook2 WHERE Id =:stdPbId LIMIT 1];
        System.debug(':::PriceBook:::'+pb.Id+ ' '+pb.Validity_Date__c+' '+pb.Name);
        
        
        PricebookEntry pbEntry = [SELECT Id,Validity_Date__c,Name,Pricebook2Id FROM PricebookEntry WHERE Pricebook2Id =:stdPbId AND Id=:pbe.Id LIMIT 1];
        System.debug(':::PriceBookEntry:::'+pbEntry.Id+ ' '+pbEntry.Validity_Date__c+' '+pbEntry.Pricebook2Id);*/
        
        // -------------------------------
        // Opportunity Line Item
        // -------------------------------
        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 100,
            UnitPrice = 100
        );
        
        opp.StageName = 'Quotation';
        update opp;
        
        // -------------------------------
        // Quote
        // -------------------------------
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = oppId,
            BillingName = 'Billing Name',
            Additional_Terms_and_Condition__c = 'this is sample text'
        );
        insert q;
        qId = q.Id;
        
        // -------------------------------
        // Quote Line Item
        // -------------------------------
        insert new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Product2Id = prod.Id,
            Quantity = 100,
            UnitPrice = 100
        );
        
        q.Status = 'Accepted';        
        
        update q;
        
        
        // -------------------------------
        // Purchase Order
        // -------------------------------
        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'PO-001',
            Opportunity__c = opp.Id,
            Quote__c = q.Id,
            PO_Approval_Status__c = 'Draft',
            PO_Date__c = Date.today()
        );
        insert po;
        poId = po.Id;
        
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
        
        po.PO_Approval_Status__c = 'Approved';
        update po;
        

        
    }
    
    // =====================================================
    // TEST: SUCCESSFUL CONTRACT CREATION
    // =====================================================
    @IsTest
    static void testMapPOToSalesContractSuccess() {
        
        
        Test.startTest();
        Opportunity opp = [
            SELECT Id, StageName, Quote_status__c, PO_Received__c
            FROM Opportunity
            WHERE PO_Received__c = 'Yes'
            LIMIT 1
        ];
        
        Quote q = [
            SELECT Id, Status, OpportunityId
            FROM Quote
            WHERE OpportunityId = :opp.Id
            LIMIT 1
        ];
        
        Purchase_Order__c po = [
            SELECT Id, PO_Approval_Status__c, Opportunity__c, Quote__c
            FROM Purchase_Order__c
            WHERE Opportunity__c = :opp.Id
            AND Quote__c = :q.Id
            LIMIT 1
        ];
        
        Contract con = new Contract(
            Opportunity__c = opp.Id,
            Purchase_Order_Name__c = po.Id,
            Contract_TypeNew__c = 'ZZSF',
            Quote_Name__c = q.Id
        );
        

        try {
            insert con;
        } catch (DmlException e) {
            // Org Flow may block Contract insert in some orgs; call handler directly
            SalesContractTriggerHandler.mapPOToSalesContract(new List<Contract>{ con });
        }
        
        List<Sales_Contract_Line_Item__c> lines =
            [SELECT Id FROM Sales_Contract_Line_Item__c WHERE Contract__c = :con.Id];
        
        Test.stopTest();
        System.assertEquals(1, lines.size(),
                            'Sales Contract Line Item should be created');
    }
    
    // =====================================================
    // TEST: DRAFT CONTRACT BLOCKED FOR SAME PO
    // =====================================================
    @IsTest
    static void testDraftContractBlocked() {
        
        Test.startTest();
        Opportunity opp = [
            SELECT Id, StageName, Quote_status__c, PO_Received__c
            FROM Opportunity
            WHERE PO_Received__c = 'Yes'
            LIMIT 1
        ];
        
        Quote q = [
            SELECT Id, Status, OpportunityId
            FROM Quote
            WHERE OpportunityId = :opp.Id
            LIMIT 1
        ];
        
        Purchase_Order__c po = [
            SELECT Id, PO_Approval_Status__c, Opportunity__c, Quote__c
            FROM Purchase_Order__c
            WHERE Opportunity__c = :opp.Id
            AND Quote__c = :q.Id
            LIMIT 1
        ];
        
        Contract first = new Contract(
            Opportunity__c = opp.Id,
            Purchase_Order_Name__c = po.Id,
            Contract_TypeNew__c = 'ZZSF',
            Quote_Name__c = q.Id
        );
        insert first;
        
        Contract duplicate = first.clone(false, true, false, false);
        
        Database.SaveResult sr = Database.insert(duplicate, false);
        Test.stopTest();
        
        System.assert(!sr.isSuccess(),
                      'Duplicate draft contract must be blocked');
    }
    
    // =====================================================
    // TEST: APPROVED QUANTITY VALIDATION
    // =====================================================
    @IsTest
    static void testApprovedQuantityExceeded() {
        
        Test.startTest();
        Opportunity opp = [
            SELECT Id, StageName, Quote_status__c, PO_Received__c
            FROM Opportunity
            WHERE PO_Received__c = 'Yes'
            LIMIT 1
        ];
        
        Quote q = [
            SELECT Id, Status, OpportunityId
            FROM Quote
            WHERE OpportunityId = :opp.Id
            LIMIT 1
        ];
        
        Purchase_Order__c po = [
            SELECT Id, PO_Approval_Status__c, Opportunity__c, Quote__c
            FROM Purchase_Order__c
            WHERE Opportunity__c = :opp.Id
            AND Quote__c = :q.Id
            LIMIT 1
        ];
        
        Contract con = new Contract(
            Opportunity__c = opp.Id,
            Purchase_Order_Name__c = po.Id,
            Contract_TypeNew__c = 'ZZSF',
            Quote_Name__c = q.Id
        );
        
        insert con;
        
        insert new Sales_Contract_Line_Item__c(
            Contract__c = con.Id,
            Product__c = prodId,
            Quantity__c = 20,
            List_Price__c = 100,
            Product_Number__c = 'P-100'
        );
        
        con.ContractApprovalStatus__c = 'Approved';
        
        Database.SaveResult sr = Database.update(con, false);
        Test.stopTest();
        
        
    }
    
    // =====================================================
    // TEST: FREEZE APPROVED CONTRACT
    // =====================================================
    @IsTest
    static void testFreezeApprovedContract() {
        
        Test.startTest();
        Opportunity opp = [
            SELECT Id, StageName, Quote_status__c, PO_Received__c
            FROM Opportunity
            WHERE PO_Received__c = 'Yes'
            LIMIT 1
        ];
        
        Quote q = [
            SELECT Id, Status, OpportunityId
            FROM Quote
            WHERE OpportunityId = :opp.Id
            LIMIT 1
        ];
        
        Purchase_Order__c po = [
            SELECT Id, PO_Approval_Status__c, Opportunity__c, Quote__c
            FROM Purchase_Order__c
            WHERE Opportunity__c = :opp.Id
            AND Quote__c = :q.Id
            LIMIT 1
        ];
        
        
        
        Contract con = new Contract(
            Opportunity__c = opp.Id,
            Purchase_Order_Name__c = po.Id,
            Contract_TypeNew__c = 'ZZSF',
            Quote_Name__c = q.Id
        );
        
        insert con;
        
        con.ContractApprovalStatus__c = 'Approved';
        update con;
        
        con.Description = 'Illegal Edit';
        
        
        Database.SaveResult sr = Database.update(con, false);
        Test.stopTest();
        
        System.assert(!sr.isSuccess(),
                      'Approved contract must be frozen');
    }
    
    // =====================================================
    // TEST: ALLOWED FIELD UPDATE ON APPROVED CONTRACT
    // =====================================================
    @IsTest
    static void testAllowedFieldOnApprovedContract() {
        
        Test.startTest();
        Opportunity opp = [
            SELECT Id, StageName, Quote_status__c, PO_Received__c
            FROM Opportunity
            WHERE PO_Received__c = 'Yes'
            LIMIT 1
        ];
        
        Quote q = [
            SELECT Id, Status, OpportunityId
            FROM Quote
            WHERE OpportunityId = :opp.Id
            LIMIT 1
        ];
        
        Purchase_Order__c po = [
            SELECT Id, PO_Approval_Status__c, Opportunity__c, Quote__c,Quantity__c
            FROM Purchase_Order__c
            WHERE Opportunity__c = :opp.Id
            AND Quote__c = :q.Id
            LIMIT 1
        ];
        
        Purchase_Order_Line_Item__c poLineItem = [
            SELECT Id,Quantity__c
            FROM Purchase_Order_Line_Item__c
            WHERE Purchase_Order__c =:po.Id
        ]; 
        
        System.debug(':::PO Line Item:::'+ poLineItem.Id+' '+poLineItem.Quantity__c);
        
        
        
        
        
        Contract con = new Contract(
            Opportunity__c = opp.Id,
            Purchase_Order_Name__c = po.Id,
            Contract_TypeNew__c = 'ZZSF',
            Quote_Name__c = q.Id
        );
        
        insert con;
        
        
        con.Trigger_SAP_Insert__c = true;
        
        
        update con;
        Test.stopTest();
        
        Contract refreshed =
            [SELECT Trigger_SAP_Insert__c FROM Contract WHERE Id = :con.Id];
        
        System.assertEquals(true, refreshed.Trigger_SAP_Insert__c,
                            'Allowed field update should succeed');
    }
    
    @IsTest
    static void testValidateApprovedQuantity_ExceedsPOLimit() {
        
        // Use data from @TestSetup
		Test.startTest();
        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            WHERE PO_Received__c = 'Yes'
            LIMIT 1
        ];
        
        Purchase_Order__c po = [
            SELECT Id
            FROM Purchase_Order__c
            WHERE Opportunity__c = :opp.Id
            LIMIT 1
        ];
        
        Quote q = [
            SELECT Id
            FROM Quote
            WHERE OpportunityId = :opp.Id
            LIMIT 1
        ];
        
        
        
        // First contract
        Contract firstCon =
            createContract(opp.Id, po.Id, q.Id);
        
        Sales_Contract_Line_Item__c cli =
            getContractLineItem(firstCon.Id);
        
        cli.Quantity__c = 50;
        update cli;
        
        firstCon.ContractApprovalStatus__c = 'Approved';
        update firstCon;
        
        // Second contract (should respect remaining quantity)
        Contract secondCon =
            createContract(opp.Id, po.Id, q.Id);
        
        Test.stopTest();
        
        Sales_Contract_Line_Item__c secondCli =
            getContractLineItem(secondCon.Id);
        
        System.assertEquals(
            50,
            secondCli.Quantity__c,
            'Remaining quantity must carry forward'
        );
    }
    
        // =====================================================
        // TEST: PREVENT REACTIVATING REJECTED CONTRACT
        // =====================================================
        @IsTest
        static void testPreventReactivatingRejectedContract() {
            
            Test.startTest();
            // Use shared setup data
            Opportunity opp = [
                SELECT Id
                FROM Opportunity
                WHERE PO_Received__c = 'Yes'
                LIMIT 1
            ];
            
            Purchase_Order__c po = [
                SELECT Id
                FROM Purchase_Order__c
                WHERE Opportunity__c = :opp.Id
                LIMIT 1
            ];
            
            Quote q = [
                SELECT Id
                FROM Quote
                WHERE OpportunityId = :opp.Id
                LIMIT 1
            ];
            
            // -------------------------------------------------
            // Create an ACTIVE contract (Draft)
            // -------------------------------------------------
            Contract activeCon = new Contract(
                Opportunity__c = opp.Id,
                Purchase_Order_Name__c = po.Id,
                Contract_TypeNew__c = 'ZZSF',
                Quote_Name__c = q.Id,
                ContractApprovalStatus__c = 'Rejected'
            );
            insert activeCon;
            Test.stopTest();
            
            
            
            // -------------------------------------------------
            // Create a REJECTED contract for same PO
            // -------------------------------------------------
            Contract rejectedCon = new Contract(
                Opportunity__c = opp.Id,
                Purchase_Order_Name__c = po.Id,
                Contract_TypeNew__c = 'ZZSF',
                Quote_Name__c = q.Id,
                ContractApprovalStatus__c = 'Draft'
            );
            insert rejectedCon;
            
            rejectedCon.ContractApprovalStatus__c = 'Approved';
            update rejectedCon;
            
            
            
            // -------------------------------------------------
            // Attempt to reactivate rejected contract
            // -------------------------------------------------
            activeCon.ContractApprovalStatus__c = 'Approved';
            
            Database.SaveResult sr = Database.update(activeCon, false);
            
            // -------------------------------------------------
            // Assert BLOCKED
            // -------------------------------------------------
            System.assertEquals(
                false,
                sr.isSuccess(),
                'Reactivating rejected contract must be blocked'
            );
            
            System.assert(
                sr.getErrors()[0].getMessage().contains('already exists for this Purchase Order'),
                'Expected active contract conflict error message'
            );
        }
}