@IsTest
public class SalesOrderTriggerHandlerNewTest {

    @TestSetup
    static void setupData() {
        
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
        Order ord= new Order(
            AccountId = acc.Id,
            ContractId = con.Id,
            OpportunityId = opp.Id,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = stdPbId,
            Delivery_Schedule_Line_Number__c = 4564
        );
        insert ord;

        insert new OrderItem(
            OrderId = ord.Id,
            Product2Id = prod.Id,
            Quantity = 5,
            UnitPrice = 100,
            PricebookEntryId = pbe.Id
        );
    }

    /* ---------------------------------------------
       TEST: Successful approval (no error)
       --------------------------------------------- */
    @IsTest
    static void testApproveOrderWithinLimit() {

        Order ord = [SELECT Id, Status FROM Order LIMIT 1];

        Test.startTest();
        ord.Sales_Order_Approval__c = 'Approved';
        update ord; // fires trigger → validateApprovalQuantities
        Test.stopTest();

        Order updated = [SELECT Status,Sales_Order_Approval__c FROM Order WHERE Id = :ord.Id];
        System.assertEquals('Approved', updated.Sales_Order_Approval__c);
    }

    /* ---------------------------------------------
       TEST: Quantity exceeded → validation error
       --------------------------------------------- */
    @IsTest
    static void testApprovalQuantityExceeded() {

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contract con = [SELECT Id FROM Contract LIMIT 1];
        PricebookEntry pbe = [SELECT Id, Product2Id,Pricebook2Id FROM PricebookEntry LIMIT 1];
        
        System.debug('Test'+acc+' '+opp+' '+' '+con+' '+pbe);

        
        Order secondOrder= new Order(
            AccountId = acc.Id,
            ContractId = con.Id,
            OpportunityId = opp.Id,
            EffectiveDate = Date.today(),
            Status='Draft',
            Pricebook2Id = pbe.Pricebook2Id,
            Delivery_Schedule_Line_Number__c = 4564
        );
        insert secondOrder;

        insert new OrderItem(
            OrderId = secondOrder.Id,
            Product2Id = pbe.Product2Id,
            Quantity = 10, // exceeds remaining
            UnitPrice = 100,
            PricebookEntryId = pbe.Id
        );

        Test.startTest();
        try {
            secondOrder.Status = 'Approved';
            update secondOrder;
            System.assert(false, 'Approval should have failed');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('exceed'),
                'Expected quantity exceed validation'
            );
        }
        Test.stopTest();
    }

    /* ---------------------------------------------
       TEST: No approving orders → early return
       --------------------------------------------- */
    @IsTest
    static void testNoApprovalChange() {

        Order ord = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        ord.EffectiveDate = Date.today().addDays(1);
        update ord; // no status change
        Test.stopTest();

        System.assert(true, 'No exception expected');
    }
}