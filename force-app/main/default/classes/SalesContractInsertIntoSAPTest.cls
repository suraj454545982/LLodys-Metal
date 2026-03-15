@IsTest
public class SalesContractInsertIntoSAPTest {

    /* -------------------------------
       TEST DATA SETUP (SAME FLOW)
    -------------------------------- */
    @TestSetup
    static void setupData() {

        Id stdPb = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPb, IsActive = true);

        Account acc = new Account(
            Name = 'Test Account',
            Phone = '9999999999',
            SAP_Customer_Code__c = 'SAP1234',
            Organization_Code__c = '2000',
            Distribution_Channel__c = '20',
            Division__c = '0'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Draft',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            Category__c = 'Iron Ore',
            Plant_and_Shipping_Point__c = '2060'
        );
        insert opp;

        Product2 prod = new Product2(
            Name = 'Iron Ore',
            IsActive = true,
            Family = 'Iron Ore',
            Plant__c = '2060'
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPb,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            ApprovalStatus_c__c = 'Approved',
            Validity_Date__c = Date.today().addYears(2)
        );
        insert pbe;

        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            
            UnitPrice = 100
        );

        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            
            BillingName = 'billing',
            Additional_Terms_and_Condition__c = 'terms'
        );
        insert q;
        
         QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );
        insert qli;
        
        
        q.Status = 'Accepted';
        update q;
        
        opp.StageName = 'Closed Won';
        opp.PO_Received__c = 'Yes';
        update opp;

        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'PO-1',
            Opportunity__c = opp.Id,
            Quote__c = q.Id,
            PO_Approval_Status__c = 'Approved',
            PO_Date__c = Date.today()
        );
        insert po;

        Contract con = new Contract(
            Opportunity__c = opp.Id,
            Purchase_Order_Name__c = po.Id,
            Contract_TypeNew__c = 'ZZSF'
            
        );
        insert con;

        insert new Sales_Contract_Line_Item__c(
            Contract__c = con.Id,
            //Product_Code__c = 'P-100',
            Target_Quantity__c = 10,
            //Unit_Of_Measure__c = 'MT',
            CurrencyIsoCode = 'INR',
            Pricing_Conditions__c =
                '{"Pricing_Conditions":[{"Condition_type":"PR00","Amount":"100","Condition_Unit":"INR"}]}'
        );
    }

    /* -------------------------------
       TEST BATCH – SUCCESS PATH
    -------------------------------- */
    @IsTest
    static void testBatchExecutionSuccess() {

        Test.setMock(HttpCalloutMock.class, new SAPContractInsertMock());

        Set<Id> conIds = new Set<Id>(
            [SELECT Id FROM Contract].getSObjectType() == Contract.SObjectType
            ? new Map<Id, Contract>([SELECT Id FROM Contract]).keySet()
            : new Set<Id>()
        );

        Test.startTest();
        Database.executeBatch(
            new SalesContractInsertOutboundCalloutToSAP(conIds),
            1
        );
        Test.stopTest();

        // No assertions as requested
        System.assert(true);
    }
}