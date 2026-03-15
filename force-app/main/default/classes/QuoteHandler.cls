public class QuoteHandler {
    
    private static final Integer MAX_QUOTES_PER_OPP = Integer.valueof(System.Label.MaxQuotes); // Max sub-numbers per opportunity
    private static final String BASE_QUOTE_NUMBER = System.Label.QuoteStartNumber; // Starting quote number
    
    public static void preventEditAfterAccepted(
        List<Quote> newList,
        Map<Id, Quote> oldMap
    ) {
        for (Quote q : newList) {
            Quote oldQ = oldMap.get(q.Id);
            
            // If quote was already Accepted
            if (oldQ.Status == 'Accepted') {
                q.addError(
                    'You cannot edit this Quote because it is already Accepted.'
                );
            }
        }
    }
    
    public static void pricingRefresh(Set<Id> quoteIds) {
        
        // Get Purchase Orders from Quote
        List<Purchase_Order__c> pos = [
            SELECT Id, Quote__c
            FROM Purchase_Order__c
            WHERE Quote__c IN :quoteIds
        ];
        
        if (pos.isEmpty()) return;
        
        Set<Id> poIds = new Set<Id>();
        Map<Id, Id> poToQuoteMap = new Map<Id, Id>();
        
        for (Purchase_Order__c po : pos) {
            poIds.add(po.Id);
            poToQuoteMap.put(po.Id, po.Quote__c);
        }
        
        // Get Contracts
        List<Contract> contracts = [
            SELECT Id, Purchase_Order_Name__c
            FROM Contract
            WHERE Purchase_Order_Name__c IN :poIds
        ];
        
        if (contracts.isEmpty()) return;
        
        Set<Id> contractIds = new Set<Id>();
        Map<Id, Id> contractToQuoteMap = new Map<Id, Id>();
        
        for (Contract c : contracts) {
            contractIds.add(c.Id);
            contractToQuoteMap.put(
                c.Id,
                poToQuoteMap.get(c.Purchase_Order_Name__c)
            );
        }
        
        // Get Contract Line Items
        List<Sales_Contract_Line_Item__c> clis = [
            SELECT Id,
            Pricing_Conditions__c,
            List_Price__c,
            GST_Tax_Percentage__c,
            CurrencyIsoCode,
            Contract__c
            FROM Sales_Contract_Line_Item__c
            WHERE Contract__c IN :contractIds
        ];
        
        if (clis.isEmpty()) return;
        
        // Get Quotes
        Map<Id, Quote> quoteMap = new Map<Id, Quote>([
            SELECT Id, BillingState,BillingStateCode,Shipping_Address_Lookup__c, Shipping_Address_Lookup__r.Shipping_Address__StateCode__s
            FROM Quote
            WHERE Id IN :quoteIds
        ]);
        
        // Rebuild pricing
        for (Sales_Contract_Line_Item__c cli : clis) {
            
            Id quoteId = contractToQuoteMap.get(cli.Contract__c);
            if (quoteId == null) continue;
            
            Quote q = quoteMap.get(quoteId);
            if (q == null) continue;
            
            PricingConditionController.rebuildPricingConditionsForCLIs(
                new List<Sales_Contract_Line_Item__c>{ cli },
                q
            );
        }
        
        if (!clis.isEmpty()) {
            update clis;
        }
    }
    
    public static void validateAcceptedQuote(List<Quote> newQuotes) {
        
        // Collect Opportunity Ids from incoming quotes
        Set<Id> oppIds = new Set<Id>();
        for (Quote q : newQuotes) {
            if (q.OpportunityId != null) {
                oppIds.add(q.OpportunityId);
            }
        }
        
        if (oppIds.isEmpty()) return;
        
        // Query if any existing quote is already Accepted for these Opps
        Map<Id, Quote> oppToAcceptedQuote = new Map<Id, Quote>();
        
        for (Quote q : [
            SELECT Id, OpportunityId, Status
            FROM Quote
            WHERE OpportunityId IN :oppIds
            AND Status = 'Accepted'
            LIMIT 50000
        ]) {
            oppToAcceptedQuote.put(q.OpportunityId, q);
        }
        
        // Validate incoming quotes
        for (Quote q : newQuotes) {
            if (oppToAcceptedQuote.containsKey(q.OpportunityId)) {
                q.addError(
                    'You cannot create a new Quote because an Accepted Quote already exists for this Opportunity.'
                );
            }
        }
    }
    
    /**
* @description Handles before insert operations for Quote records
* @param newQuotes List of new Quote records
*/
    public void handleBeforeInsert(List<Quote> newQuotes) {
        if (newQuotes == null || newQuotes.isEmpty()) {
            return;
        }
        
        try {
            validateQuoteBeforeInsert(newQuotes);
            // Directly set field value, no DML needed
            for (Quote q : newQuotes) {
                q.Hide_Fields__c = true;
            }
            
            assignQuoteNumbers(newQuotes);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Quote number assignment failed: ' + e.getMessage());
            newQuotes[0].addError('Failed to assign quote number: ' + e.getMessage());
        }
    }
    
    public static void validateQuoteBeforeInsert(List<Quote> newQuotes) {
        // Collect Opportunity IDs from Quotes
        Set<Id> opportunityIds = new Set<Id>();
        for (Quote quote : newQuotes) {
            if (quote.OpportunityId != null) {
                opportunityIds.add(quote.OpportunityId);
            }
        }
        
        // Exit if no Opportunities to check
        if (opportunityIds.isEmpty()) return;
        
        // Query Opportunities with their OpportunityLineItems and StageName
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([
            SELECT Id, StageName, 
            (SELECT Id FROM OpportunityLineItems LIMIT 1)
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ]);
        
        // Validate each Quote
        for (Quote quote : newQuotes) {
            if (quote.OpportunityId != null) {
                Opportunity relatedOpp = oppMap.get(quote.OpportunityId);
                
                // Check if Opportunity exists
                if (relatedOpp == null) {
                    quote.addError('Related Opportunity does not exist.');
                    continue;
                }
                
                // Check if Opportunity has at least one OpportunityLineItem
                if (relatedOpp.OpportunityLineItems.isEmpty()) {
                    quote.addError('The related Opportunity must have at least one Opportunity Line Item.');
                }
                
                // Check if Opportunity Stage is not 'Schedule Meeting' or 'Qualification'
                if (relatedOpp.StageName != null && 
                    (relatedOpp.StageName.equalsIgnoreCase('Schedule Meeting') || 
                     relatedOpp.StageName.equalsIgnoreCase('Qualification'))) {
                         //quote.addError('The related Opportunity Stage cannot be Schedule Meeting or Qualification.');
                     }
            } else {
                quote.addError('Quote must be associated with an Opportunity.');
            }
        }
    } 
    
    /**
* @description Assigns quote numbers to new quotes based on Opportunity
* @param newQuotes List of Quote records to process
*/
    private void assignQuoteNumbers(List<Quote> newQuotes) {
        // Since only one quote is created at a time, process single quote
        Quote newQuote = newQuotes[0];
        if (newQuote.OpportunityId == null) {
            return;
        }
        
        // Query existing quotes for the opportunity
        List<Quote> existingQuotes = [
            SELECT Id, Quote_Number__c
            FROM Quote
            WHERE OpportunityId = :newQuote.OpportunityId
            AND Quote_Number__c != null
            ORDER BY CreatedDate ASC
            LIMIT 1000
        ];
        
        // Initialize the next base number
        String nextBaseNumber = BASE_QUOTE_NUMBER;
        
        // Find highest used base number across all quotes
        AggregateResult[] maxBaseResults = [
            SELECT MAX(Quote_Number__c) maxBase
            FROM Quote
            WHERE Quote_Number__c != null
            AND Quote_Number__c NOT IN ('%.%')
        ];
        
        if (!maxBaseResults.isEmpty() && maxBaseResults[0].get('maxBase') != null) {
            String maxUsed = (String)maxBaseResults[0].get('maxBase');
            
            // Convert to decimal for comparison, then back to string
            Decimal maxUsedNum = Decimal.valueOf(maxUsed);
            Decimal nextBaseNum = Decimal.valueOf(nextBaseNumber);
            
            if (maxUsedNum >= nextBaseNum) {
                nextBaseNumber = String.valueOf(maxUsedNum + 1).split('\\.')[0];
            }
        }
        
        if (existingQuotes.isEmpty()) {
            // First quote for this opportunity
            newQuote.Quote_Number__c = nextBaseNumber;
        } else {
            // Subsequent quote - use base number from first quote
            String baseNumber = getBaseNumber(existingQuotes[0].Quote_Number__c);
            Integer nextSubNumber = getNextSubNumber(existingQuotes);
            
            if (nextSubNumber > MAX_QUOTES_PER_OPP) {
                newQuote.addError('Maximum quote limit reached for Opportunity');
                return;
            }
            
            newQuote.Quote_Number__c = baseNumber + '.' + String.valueOf(nextSubNumber).leftPad(3, '0');
        }
    }
    
    /**
* @description Extracts base number from quote number
* @param quoteNumber The quote number to parse
* @return Base number portion
*/
    private String getBaseNumber(String quoteNumber) {
        if (String.isBlank(quoteNumber)) {
            return BASE_QUOTE_NUMBER;
        }
        return quoteNumber.split('\\.')[0];
    }
    
    /**
* @description Gets next available sub-number for quotes
* @param quotes List of existing quotes
* @return Next available sub-number
*/
    private Integer getNextSubNumber(List<Quote> quotes) {
        Integer highestSubNumber = 0;
        for (Quote quote : quotes) {
            if (String.isNotBlank(quote.Quote_Number__c) && quote.Quote_Number__c.contains('.')) {
                String[] parts = quote.Quote_Number__c.split('\\.');
                if (parts.size() > 1 && parts[1].isNumeric()) {
                    Integer subNumber = Integer.valueOf(parts[1]);
                    highestSubNumber = Math.max(highestSubNumber, subNumber);
                }
            }
        }
        return highestSubNumber + 1;
    }    
    
    // Prevent manual modification of Quote_Number__c
    public void handleBeforeUpdate(List<Quote> newQuotes, Map<Id, Quote> oldQuoteMap) {
        for (Quote quote : newQuotes) {
            Quote oldQuote = oldQuoteMap.get(quote.Id);
            if (quote.Quote_Number__c != oldQuote.Quote_Number__c) {
                quote.addError('Quote Number cannot be modified.');
            }
        }
    }
    
    //Updating Quote Status in Opportunity when Quote is Accepted
    public Void handleAfterUpdate(List<Quote> newQuotes, Map<Id, Quote> oldQuoteMap){
        List<Opportunity> updateOpp = new List<Opportunity>();
        for (Quote quote : newQuotes) {
            Quote oldQuote = oldQuoteMap.get(quote.Id);
            if (quote.Status != oldQuote.Status && quote.Status=='Accepted') {
                Opportunity uOpp = new opportunity(Id=quote.OpportunityId,Quote_status__c='Accepted');
                updateOpp.add(uOpp);
            }
        }
        if(updateOpp.size()>0){
            update updateOpp;
        }
    }
    
    //Added by Simon
    //for recalculating the taxes on State Update
    public static void refreshTaxes(
        List<Quote> newQuotes,
        Map<Id, Quote> oldQuoteMap
    ){
        
        Set<Id> quoteIds = new Set<Id>();
        
        for(Quote q : newQuotes){
            
            Quote oldQ = oldQuoteMap.get(q.Id);
            
            if(
                q.BillingStateCode != oldQ.BillingStateCode ||
                q.Shipping_Address_Lookup__c != oldQ.Shipping_Address_Lookup__c
            ){
                quoteIds.add(q.Id);
            }
        }
        
        if(quoteIds.isEmpty()) return;
        
        List<QuoteLineItem> lines = [
            SELECT Id FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
        ];
        
        if(!lines.isEmpty()){
            update lines;
        }
    }
   
    public static void validateRejectionComments(List<Quote> newList, Map<Id, Quote> oldMap) {
        Map<Id, Quote> rejectedQuotes = new Map<Id, Quote>();
        
        for (Quote q : newList) {
            Quote oldQ = oldMap.get(q.Id);
            
            // FIXED lowercase comparison	
            if (
                oldQ.Status != null &&
                q.Status != null &&
                oldQ.Status.toLowerCase() != 'Approved' &&
                q.Status.toLowerCase() == 'Approved'
            ) {
                rejectedQuotes.put(q.Id, q);
            }
        }
        
        if (rejectedQuotes.isEmpty()) return;
        SYSTEM.DEBUG('----rejectedQuotes:::'+rejectedQuotes);
        List<Id> processInstanceIds = new List<Id>();
        
        List<Quote> quotesWithPI = [
            SELECT (SELECT Id FROM ProcessInstances ORDER BY CreatedDate DESC LIMIT 1)
            FROM Quote
            WHERE Id IN :rejectedQuotes.keySet()
        ];
        SYSTEM.DEBUG('----quotesWithPI:::'+quotesWithPI);
        
        for (Quote q : quotesWithPI) {
            if (!q.ProcessInstances.isEmpty()) {
                processInstanceIds.add(q.ProcessInstances[0].Id);
            }
        }
        
        if (processInstanceIds.isEmpty()) return;
        
        List<ProcessInstance> processInstances = [
            SELECT TargetObjectId,
            (SELECT Id, StepStatus, Comments 
             FROM Steps 
             WHERE StepStatus = 'Rejected' 
             ORDER BY CreatedDate DESC LIMIT 1)
            FROM ProcessInstance
            WHERE Id='04gez0000004Ij8AAE'
        ];
        
        for (ProcessInstance pi : processInstances) {
            //system.debug(' pi.Steps[0].Comments-->'+ pi.Steps[0].Comments);
            if (
                
                pi.Steps.isEmpty() ||
                pi.Steps[0].Comments == null ||
                pi.Steps[0].Comments.trim().length() == 0
            ) {
                rejectedQuotes.get(pi.TargetObjectId)
                    .addError('Please provide a rejection reason!');
            }
        }
    }
    
}