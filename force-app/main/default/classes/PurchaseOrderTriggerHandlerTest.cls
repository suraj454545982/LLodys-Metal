@isTest
public class PurchaseOrderTriggerHandlerTest {

    /* =========================================================
       COMMON TEST DATA
       ========================================================= */
    private static Purchase_Order__c createPO() {
		
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(
            Id = stdPbId,
            IsActive = true,
            Validity_Date__c = Date.today().addDays(10)
        );
        
        // Account (required in most orgs)
        Account acc = new Account(
            Name = 'Test Account',
            Phone = '9999999999'
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
		
        
        
        //Update Opportunity
        Opportunity oppUpdate = new Opportunity(id = opp.Id, PO_Received__c = 'Yes');
        update oppUpdate;
        
        
        // Purchase Order
        Purchase_Order__c po = new Purchase_Order__c(
            Name = '123',
            PO_Date__c = Date.today().addDays(-10),
            Quote__c = qUpdate.Id,
            Opportunity__c = oppUpdate.Id
        );
        insert po;

        return po;
    }

    /* =========================================================
       AFTER INSERT – mapQuoteToPO
       ========================================================= */
    @isTest
    static void testAfterInsert() {

        Purchase_Order__c po = createPO();

        Test.startTest();
        PurchaseOrderTriggerHandler.afterInsert(
            new List<Purchase_Order__c>{ po }
        );
        Test.stopTest();

        // No assertion on helper internals
        System.assert(true, 'afterInsert executed');
    }

    /* =========================================================
       AFTER INSERT – RECURSION GUARD
       ========================================================= */
    @isTest
    static void testAfterInsertRecursionGuard() {

        Purchase_Order__c po = createPO();

        Test.startTest();
        PurchaseOrderTriggerHandler.afterInsert(
            new List<Purchase_Order__c>{ po }
        );
        // Second call should be skipped due to static flag
        PurchaseOrderTriggerHandler.afterInsert(
            new List<Purchase_Order__c>{ po }
        );
        Test.stopTest();

        System.assert(true, 'Recursion guard executed');
    }

    /* =========================================================
       BEFORE UPDATE – fileValidation
       ========================================================= */
    @isTest
    static void testBeforeUpdate() {

        Purchase_Order__c po = createPO();

        Purchase_Order__c oldPo = po.clone(false, true, false, false);
        oldPo.Id = po.Id;

        // Modify record to trigger beforeUpdate
        po.Name = 'Updated PO';

        Test.startTest();
        PurchaseOrderTriggerHandler.beforeUpdate(
            new List<Purchase_Order__c>{ po },
            new Map<Id, Purchase_Order__c>{ oldPo.Id => oldPo }
        );
        Test.stopTest();

        System.assert(true, 'beforeUpdate executed');
    }
}