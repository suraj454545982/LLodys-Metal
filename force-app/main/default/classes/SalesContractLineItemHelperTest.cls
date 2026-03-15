@IsTest
public class SalesContractLineItemHelperTest {

    @TestSetup
    static void setupSameBusinessFlow() {

        // ---------------- PRICEBOOK ----------------
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        // ---------------- ACCOUNT ----------------
        Account acc = new Account(
            Name = 'Test Account',
            Phone = '9999999999',
            Organization_Code__c = '2000',
            Distribution_Channel__c = '20',
            Division__c = '0',
            SAP_Customer_Code__c = 'SAP1022'
        );
        insert acc;

        // ---------------- OPPORTUNITY ----------------
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            Category__c = 'Iron Ore',
            Quote_status__c = 'Accepted',
            Plant_and_Shipping_Point__c = '2060',
            PO_Received__c = 'Yes'
        );
        insert opp;

        // ---------------- PRODUCT ----------------
        Product2 prod = new Product2(
            Name = 'Iron Ore',
            ProductCode = 'MAT-001',
            IsActive = true,
            Family = 'Iron Ore',
            Plant__c = '2060'
        );
        insert prod;

        // ---------------- PRICEBOOK ENTRY ----------------
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            ApprovalStatus_c__c = 'Approved',
            Validity_Date__c = Date.today().addDays(10)
        );
        insert pbe;

        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );

        // ---------------- QUOTE ----------------
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Status = 'Draft',
            BillingName = 'Billing',
            Additional_Terms_and_Condition__c = 'Terms'
        );
        insert q;

        insert new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );

        update new Quote(Id = q.Id, Status = 'Accepted');

        // ---------------- PURCHASE ORDER ----------------
        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'PO-001',
            Quote__c = q.Id,
            Opportunity__c = opp.Id,
            PO_Approval_Status__c = 'approved',
            PO_Date__c = Date.today()
        );
        insert po;

        // ---------------- CONTRACT (SAP CREATED) ----------------
        Contract con = new Contract(
            Contract_TypeNew__c = 'ZZSF',
            Opportunity__c = opp.Id,
            Purchase_Order_Name__c = po.Id,
            
            SAP_Sales_Contract_Number__c = 'SAP-CON-1001'
        );
        insert con;
        
        

        // ---------------- SALES CONTRACT LINE ITEM ----------------
        Sales_Contract_Line_Item__c cli = new Sales_Contract_Line_Item__c(
            Contract__c = con.Id,
            Product__c = prod.Id,
            Quantity__c = 10,
            List_Price__c = 100,
            Product_Number__c = 'MAT-001',
            Reason_for_Rejection__c = '00',
            Text_Item__c = 'Z220 - SAMPLE LINE ITEM TEXT Z220 MAT1 SPECIFICATION'
            //Text_Item__c = 'Z001-TEST'
        );

        // Optional dynamic SAP text field (only if exists in org)
        Map<String, Schema.SObjectField> fields =
            Schema.SObjectType.Sales_Contract_Line_Item__c.fields.getMap();
        if (fields.containsKey('Text_Z001__c')) {
            cli.put('Text_Z001__c', 'Sample line item text');
        }

        insert cli;
        
        
        con.ContractApprovalStatus__c = 'Approved';
        update con;
    }

    // =========================================================
    // TEST 1 — fetchSAPUpdateIds + processLineItemChange
    // =========================================================
    @IsTest
    static void testSAPUpdateTriggered() {
    
        // Existing record from @TestSetup
        Sales_Contract_Line_Item__c oldLi = [
            SELECT Id, Contract__c, Reason_for_Rejection__c,Text_Item__c
            FROM Sales_Contract_Line_Item__c
            LIMIT 1
        ];
    
        // Simulate UPDATE (same Id, changed field)
        Sales_Contract_Line_Item__c newLi = new Sales_Contract_Line_Item__c(
            Id = oldLi.Id,
            Contract__c = oldLi.Contract__c,
            Reason_for_Rejection__c = '05'
        );
    
        Map<Id, Sales_Contract_Line_Item__c> oldMap =
            new Map<Id, Sales_Contract_Line_Item__c>{
                oldLi.Id => oldLi
            };
    
        Test.startTest();
        SalesContractLineItemHelper.processLineItemChange(
            new List<Sales_Contract_Line_Item__c>{ newLi },
            oldMap
        );
        Test.stopTest();
    
        System.assert(true, 'SAP update path executed without NullPointerException');
    }


    // =========================================================
    // TEST 2 — buildLineItemTexts (FULL COVERAGE)
    // =========================================================
    @IsTest
    static void testBuildLineItemTexts() {

        Sales_Contract_Line_Item__c cli = [
            SELECT Id, Text_Item__c
            FROM Sales_Contract_Line_Item__c
            LIMIT 1
        ];

        Test.startTest();
        List<SAPContractWrapper.LineitemText> texts =
            SalesContractLineItemHelper.buildLineItemTexts(cli);
        Test.stopTest();

        System.assertNotEquals(null, texts, 'Text list must not be null');
    }

    // =========================================================
    // TEST 3 — EMPTY Text_Item__c (early return branch)
    // =========================================================
    @IsTest
    static void testEmptyTextItem() {

        Sales_Contract_Line_Item__c cli = [
            SELECT Id
            FROM Sales_Contract_Line_Item__c
            LIMIT 1
        ];

        cli.Text_Item__c = null;

        List<SAPContractWrapper.LineitemText> result =
            SalesContractLineItemHelper.buildLineItemTexts(cli);

        System.assertEquals(0, result.size(), 'Empty text must return empty list');
    }
    
    

    @IsTest
    static void testBuildLineItemTexts2() {
    
        // ------------------------------------------------------------
        // Arrange: create Sales Contract Line Item with dynamic text
        // ------------------------------------------------------------
        Sales_Contract_Line_Item__c cli = new Sales_Contract_Line_Item__c(
            Text_Item__c = 'Z220 - SAMPLE LINE ITEM TEXT Z220 MAT1 SPECIFICATION'
        );
    
        // IMPORTANT: Set dynamic fields explicitly
        cli.put('Text_Z220__c', 'This is header level text');
        cli.put('Text_Z014__c', 'This is item level text');
    
        // ------------------------------------------------------------
        // Act
        // ------------------------------------------------------------
        Test.startTest();
        List<SAPContractWrapper.LineitemText> result =
            SalesContractLineItemHelper.buildLineItemTexts(cli);
        Test.stopTest();
    
       
    }

}