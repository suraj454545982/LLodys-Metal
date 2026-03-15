@isTest
public class QuoteCloneControllerTest {
    @isTest
    static void testCloneQuote() {
        // Create test Account
        Account acct = new Account(Name = 'Test Account', Company_Email_ID__c = 'testaccount@gmail.com',Phone='9876543210');
        insert acct;

        // Create test Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acct.Id,
            Category__c = 'Iron Ore',
            Plant_and_Shipping_Point__c = '2060'
        );
        insert opp;

        // Get Standard Pricebook ID
        Id standardPbId = Test.getStandardPricebookId();
        update new Pricebook2(
            Id = standardPbId,
            IsActive = true,
            Validity_Date__c = Date.today().addYears(2)
        );

        // Create Product
        Product2 prod = new Product2(Name = 'Test Product', IsActive = true,Plant__c ='2060',Family = 'Iron Ore');
        insert prod;

        // Create Pricebook Entry
        PricebookEntry pbe = new PricebookEntry(
            Product2Id = prod.Id,
            Pricebook2Id = standardPbId,
            UnitPrice = 100,
            IsActive = true,
            Validity_Date__c = Date.today().addyears(2),
            ApprovalStatus_c__c = 'Approved'
        );
        insert pbe;
        
        OpportunityLineItem baseOli = new OpportunityLineItem(
            OpportunityId     = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity          = 1,
            UnitPrice         = 100
            
        );
        insert baseOli;

        // Create Quote
        Quote quote = new Quote(
            Name = 'Original Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = standardPbId,
            Status = 'Draft',
            BillingName = 'billing name',
            Additional_Terms_and_Condition__c = 'this is sample text'
        );
        insert quote;

        // Create Quote Line Item
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = quote.Id,
            Product2Id = prod.Id,
            Quantity = 2,
            UnitPrice = 100,
            PricebookEntryId = pbe.Id
        );
        insert qli;

        // Instantiate controller
        Test.startTest();
        ApexPages.StandardController stdController = new ApexPages.StandardController(quote);
        QuoteCloneController controller = new QuoteCloneController(stdController);
        PageReference resultPage = controller.cloneQuote();
        Test.stopTest();

       
    }
    
    
   
    
   


}