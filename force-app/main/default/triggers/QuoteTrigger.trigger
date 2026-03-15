trigger QuoteTrigger on Quote  (before insert, before update, after insert, after update,
                                before delete, after delete, after undelete)  
{
    QuoteHandler handler = new QuoteHandler();
    
    // Before Insert
    if (Trigger.isBefore && Trigger.isInsert) {
        handler.handleBeforeInsert(Trigger.new);
    }
    
    if (Trigger.isBefore && Trigger.isInsert) {
        QuoteHandler.validateAcceptedQuote(Trigger.new);
    }
    
    if(Trigger.isBefore){
        if(Trigger.isInsert || Trigger.isUpdate){
            OppQuoteMaterialBlockService.validateOnInsertAndUpdate(Trigger.new, Trigger.oldMap);
            
        }
        if(Trigger.isUpdate){
            OppQuoteMaterialBlockService.preventQuoteAcceptanceIfOppHasBlockedProducts(Trigger.new,Trigger.oldMap);
        }
        if(Trigger.isUpdate){
            QuoteHandler.preventEditAfterAccepted(Trigger.new,Trigger.oldMap);
        }
    }
    

    
    // Before Update
    if (Trigger.isBefore && Trigger.isUpdate) {
      //   QuoteHandler.validateRejectionComments(Trigger.new,Trigger.oldMap);
        handler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
    
    // After Update
    if (Trigger.isAfter && Trigger.isUpdate) {
         
        handler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        //Recalculate Taxes on State Updation
        //This Methods Just Simply Update QuoteLineItem and the QuoteLineItem Calls the rollupOnQuote() in QuoteHandler Class
        QuoteHandler.refreshTaxes(
            Trigger.new,
            Trigger.oldMap
        );
        
    }
    
    //After Update Pricing Condition Trigger
    //If Billing State and Shipping State Changed
    if (Trigger.isAfter && Trigger.isUpdate) {
        Set<Id> quoteIds = new Set<Id>();
        
        for (Quote newQ : Trigger.new) {
            Quote oldQ = Trigger.oldMap.get(newQ.Id);
            
            if (
                newQ.BillingStateCode != oldQ.BillingStateCode ||
    			newQ.Shipping_Address_Lookup__c != oldQ.Shipping_Address_Lookup__c
            ) {
                quoteIds.add(newQ.Id);
            }
        }
        
        if (!quoteIds.isEmpty()) {
            QuoteHandler.pricingRefresh(quoteIds);
        }
    }

}