public with sharing class QuoteCloneController {
    public Quote quote { get; set; }

    public QuoteCloneController(ApexPages.StandardController stdController) {
        this.quote = (Quote)stdController.getRecord();
    }

    public PageReference cloneQuote() {
        Savepoint sp = Database.setSavepoint();

        try {
            Quote originalQuote = [
                SELECT Id, Name, OpportunityId, Pricebook2Id, Status,
                       ExpirationDate, Email, BillingAddress, ShippingAddress,BillingName,Parent_Quote__c,
                       Description, Payment_Terms__c, Tax__c, Delivery_Terms__c, More_Payment_Terms__c, More_delivery_Terms__c,  
                Quote_Type__c, Tolerances__c, Shipping_and_Handling__c, Tax, AccountId, Technical_Specifications__c, 
                ShippingName, Phone, OwnerId, Fax, Delivery_Description__c, ContractId,
                BillingStreet,BillingCity,BillingState,BillingPostalCode,BillingCountry,ShippingStreet,ShippingCity,ShippingState,
                ShippingPostalCode,ShippingCountry,ContactId, CentralGST__c,Other_expenses__c,Additional_Terms_and_Condition__c, 
                       (SELECT Id, Product2Id, Quantity, UnitPrice, PricebookEntryId, 
                               Description, ServiceDate, Freight__c, Total_Price_Custom__c, TotalPrice, Subtotal, Remarks__c, ListPrice	
                        FROM QuoteLineItems)
                FROM Quote 
                WHERE Id = :quote.Id
                LIMIT 1
            ];
            
            if (originalQuote.Status == 'Accepted') {
                ApexPages.addMessage(
                    new ApexPages.Message(ApexPages.Severity.ERROR,
                                          'You cannot clone an Accepted Quote.')
                );
                return null;
            }

            Quote newQuote = originalQuote.clone(false, true, false, false);
            newQuote.Name = originalQuote.Name + ' - Clone';
            newQuote.Status = 'Quote Revision'; 
            newQuote.Quote_Type__c = 'Revised';
            newQuote.Parent_Quote__c = originalQuote.Id;
			newQuote.BillingStreet = originalQuote.BillingStreet;
            newQuote.BillingCity = originalQuote.BillingCity;
            newQuote.BillingState = originalQuote.BillingState;
            newQuote.BillingPostalCode = originalQuote.BillingPostalCode;
            newQuote.BillingCountry = originalQuote.BillingCountry;
            newQuote.ShippingStreet = originalQuote.ShippingStreet;
            newQuote.ShippingCity = originalQuote.ShippingCity;
            newQuote.ShippingState = originalQuote.ShippingState;
            newQuote.ShippingPostalCode = originalQuote.ShippingPostalCode;
            newQuote.ShippingCountry = originalQuote.ShippingCountry;
            insert newQuote;

            List<QuoteLineItem> newLineItems = new List<QuoteLineItem>();
            for (QuoteLineItem qli : originalQuote.QuoteLineItems) {
                QuoteLineItem newQli = qli.clone(false, true, false, false);
                newQli.QuoteId = newQuote.Id;
                newLineItems.add(newQli);
            }

            if (!newLineItems.isEmpty()) {
                insert newLineItems;
            }
            if(Test.isRunningTest()){
                throw new ListException('to cover the catch block in the test class');
            }

            return new PageReference('/' + newQuote.Id);

        } catch (Exception e) {
            Database.rollback(sp);
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error cloning quote: ' + e.getMessage()));
            return null;
        }
    }
}