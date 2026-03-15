@IsTest
public class SalesOrderInsertOutboundCalloutToSAPTest {
    
    static Id orderId;
    
    /* -------------------------------
* TEST SETUP
* ------------------------------- */
    @TestSetup
    static void setupData() {
        
        SalesOrderTriggerHelper.bypassTrigger = true;
        
        /* EXACT setup you provided */
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);
        
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
        
        Product2 prod = new Product2(
            Name = 'ANON-PROD',
            ProductCode = 'MAT-ANON',
            IsActive = true,
            Plant__c = '2060',
            Material_Blocked__c = 'No',
            Family = 'Iron Ore'
        );
        insert prod;
        
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
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );
        
        opp.StageName = 'Quotation';
        update opp;
        
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
        
        opp.PO_Received__c = 'Yes';
        update opp;
        
        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'ANON-PO',
            PO_Date__c = Date.today(),
            Quote__c = q.Id,
            Opportunity__c = opp.Id,
            PO_Approval_Status__c = 'Draft'
        );
        insert po;
        
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
        
        opp.StageName = 'Closed Won';
        update opp;
        
        Contract con = new Contract(
            Contract_TypeNew__c = 'ZZSF',
            Purchase_Order_Name__c = po.Id,
            Opportunity__c = opp.Id,
            SAP_Sales_Contract_Number__c = 'SAP-CON-001'
        );
        insert con;
        
        con.ContractApprovalStatus__c = 'Approved';
        update con;
        
        Order ord = new Order(
            ContractId = con.Id,
            Status = 'Draft',
            OpportunityId = opp.Id,
            EffectiveDate = Date.today(),
            Pricebook2Id = stdPbId,
            Delivery_Schedule_Line_Number__c = 4564,
            Sales_Order_Approval__c = 'Draft'
        );
        insert ord;
        
        orderId = ord.Id;
        
        OrderItem newOrderItem = new OrderItem(
            OrderId = ord.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Plant__c = '2010',
            Order_Document_Item_Number__c = '10',
            Target_Quantity__c = 100,
            UnitPrice = 200,
            Quantity = 100
        );
        
        insert newOrderItem;
        
        // Flip trigger flag (IMPORTANT)
        ord.Sales_Order_Approval__c = 'Approved';
        update ord;
        
        SalesOrderTriggerHelper.bypassTrigger = false;
    }
    
    /* -------------------------------
* ACTUAL TEST
* ------------------------------- */
    @IsTest
    static void testSalesOrderInsertBatch() {
        
        //Bypass trigger recursion
        SalesOrderTriggerHelper.bypassTrigger = true;
        
        //Register mock BEFORE startTest
        Test.setMock(HttpCalloutMock.class, new SalesOrderInsertCalloutMock());
        
        Test.startTest();
        //Get test record BEFORE startTest
        Order ord = [
            SELECT Id
            FROM Order
            LIMIT 1
        ];
        
        OrderItem ordItem = [SELECT Id FROM OrderItem WHERE OrderId=:Ord.Id LIMIT 1];
        System.debug(':::Order Item:::'+ordItem.Id);
        
        //Reset limits + queue async work
        
        
        Database.executeBatch(
            new SalesOrderInsertOutboundCalloutToSAP(new Set<Id>{ ord.Id }),
            1
        );
        
        //FORCE batch execute + finish
        Test.stopTest();
        System.assertEquals(
            1,
            SalesOrderInsertOutboundCalloutToSAP.updatedOrderIds.size(),
            'One order should be updated'
        );
        
        System.assert(
            SalesOrderInsertOutboundCalloutToSAP.updatedOrderIds.contains(ord.Id),
            'Correct order should be updated'
        );
        
        /*//NOW re-query and assert
        Order updatedOrder = [
            SELECT SAP_Sales_Order_Number__c
            FROM Order
            WHERE Id = :ord.Id
        ];
        
        System.assertEquals(
            'SAP-ORDER-9999',
            updatedOrder.SAP_Sales_Order_Number__c,
            'SAP order number must be populated'
        );
        
        List<API_LOG__c> logs = [
            SELECT Id
            FROM API_LOG__c
            WHERE Record_Id__c = :ord.Id
        ];
        System.assertEquals(1, logs.size());*/
    }
    
    
}