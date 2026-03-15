@isTest
public class TestOfferLetterControllerExtension {
  // Setup method to create test data
    @TestSetup
    static void setupTestData() {
        // Create an Account
        Account acc = new Account(Name = 'Test Account',Company_Email_ID__c='test@gmail.com',Category__c='Iron Ore');
        insert acc;
        
        // Create a Contact
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = acc.Id,
            email= 'test@email.com'
        );
        insert con;
        
        // Create an Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = Test.getStandardPricebookId(),
            category__c='Iron Ore'
        );
        insert opp;
        
        // Create a Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            ProductCode = 'TP001',
            IsActive = true,
            QuantityUnitOfMeasure = 'Each'
        );
        insert prod;
        
        // Create a PricebookEntry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = prod.Id,
            UnitPrice = 1000.00,
            IsActive = true
        );
        insert pbe;
        
        // Create a Quote
        Quote q = new Quote(
            Name = 'Test Quote',
            ContactId = con.Id,
            OpportunityId = opp.Id, // Link to Opportunity
            BillingStreet = '123 Billing St',
            BillingCity = 'Test City',
            BillingState = 'Test State',
            BillingPostalCode = '12345',
            ShippingStreet = '123 Shipping St',
            ShippingCity = 'Test City',
            ShippingState = 'Test State',
            ShippingPostalCode = '12345',
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert q;
        
        // Create Quote Line Item
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 1000.00
        );
        insert qli;
    }
    
    // Test the constructor with a valid Quote ID
    @isTest
    static void testConstructorWithValidQuote() {
        // Retrieve the test Quote
        Quote testQuote = [SELECT Id, Name, GrandTotal FROM Quote WHERE BillingStreet = '123 Billing St' LIMIT 1];
        
        // Set up the StandardController
        ApexPages.StandardController stdController = new ApexPages.StandardController(testQuote);
        
        // Instantiate the controller extension
        OfferLetterControllerExtension controller = new OfferLetterControllerExtension(stdController);
        
        // Verify the results
        System.assertNotEquals(null, controller.quote, 'Quote should not be null');
        System.assertNotEquals(null, controller.quoteLineItemWrappers, 'QuoteLineItemWrappers should not be null');
        System.assertEquals(1, controller.quoteLineItemWrappers.size(), 'Should have one QuoteLineItemWrapper');
        System.assertEquals(1, controller.quoteLineItemWrappers[0].serialNumber, 'Serial number should be 1');
        System.assertEquals(180.00, controller.centralGST, 'Central GST should be 180.00');
        System.assertEquals(180.00, controller.stateGST, 'State GST should be 180.00');
        System.assertEquals(360.00, controller.totalGSTAmount, 'Total GST should be 360.00');
        System.assertEquals('Three Hundred Sixty Rupees Only', controller.totalTaxAmountInWords, 'Total tax amount in words should match');
    }
    
    // Test the constructor with an invalid Quote ID
    @isTest
    static void testConstructorWithInvalidQuote() {
        // Create a Quote record with no ID
        Quote invalidQuote = new Quote();
        
        // Set up the StandardController
        ApexPages.StandardController stdController = new ApexPages.StandardController(invalidQuote);
        
        // Instantiate the controller extension
        OfferLetterControllerExtension controller = new OfferLetterControllerExtension(stdController);
        
        // Verify that an error message was added
        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assertEquals(1, messages.size(), 'One error message should be present');
        System.assertEquals(ApexPages.Severity.ERROR, messages[0].getSeverity(), 'Message should be an error');
    }
    
    // Test the getQuote method
    @isTest
    static void testGetQuote() {
        // Retrieve the test Quote
        Quote testQuote = [SELECT Id, Name FROM Quote WHERE  BillingStreet = '123 Billing St' LIMIT 1];
        
        // Set up the StandardController
        ApexPages.StandardController stdController = new ApexPages.StandardController(testQuote);
        
        // Instantiate the controller extension
        OfferLetterControllerExtension controller = new OfferLetterControllerExtension(stdController);
        
        // Call getQuote
        Quote retrievedQuote = controller.getQuote();
        
        // Verify the results
        System.assertNotEquals(null, retrievedQuote, 'Retrieved quote should not be null');
        System.assertEquals(testQuote.Id, retrievedQuote.Id, 'Quote IDs should match');
    }
    
    // Test the convertNumberToWords method
    @isTest
    static void testConvertNumberToWords() {
        // Retrieve the test Quote
        Quote testQuote = [SELECT Id FROM Quote WHERE  BillingStreet = '123 Billing St' LIMIT 1];
        
        // Set up the StandardController
        ApexPages.StandardController stdController = new ApexPages.StandardController(testQuote);
        
        // Instantiate the controller extension
        OfferLetterControllerExtension controller = new OfferLetterControllerExtension(stdController);
        OfferLetterControllerExtension.saveAndEmailPDF(testQuote.Id);
        // Test various number conversions
        System.assertEquals('Zero Rupees Only', controller.convertNumberToWords(0), 'Zero amount should return correctly');
        System.assertEquals('One Hundred Rupees Only', controller.convertNumberToWords(100.00), '100 should convert correctly');
        System.assertEquals('One Thousand Rupees Only', controller.convertNumberToWords(1000.00), '1000 should convert correctly');
        System.assertEquals('One Lakh Rupees Only', controller.convertNumberToWords(100000.00), '100000 should convert correctly');
        System.assertEquals('One Crore Rupees Only', controller.convertNumberToWords(10000000.00), '10000000 should convert correctly');
        System.assertEquals('One Hundred Twenty Three Rupees and Forty Five Paise Only', controller.convertNumberToWords(123.45), '123.45 should convert correctly');
    }
}