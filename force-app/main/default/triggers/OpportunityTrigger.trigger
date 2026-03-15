trigger OpportunityTrigger on Opportunity (before insert, before update, after insert, after update,
                                           before delete, after delete, after undelete) 
{
    OpportunityHandler handler = new OpportunityHandler();
    
    // Before Insert
    if (Trigger.isBefore && Trigger.isInsert) {
        handler.handleBeforeInsert(Trigger.new);
    }
    
    // Before Update
    if (Trigger.isBefore && Trigger.isUpdate) {
       //  handler.handleBeforeInsert(Trigger.new);
        handler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        //Once PO Received 'Yes', Opportunity Stage Changes automatically to Customer Onboarding
        OpportunityPricebookHelper.validatePricebookValidity(Trigger.new);
        OpportunityPricebookHelper.validatePricebook(Trigger.new, Trigger.oldMap);
        
        
        //if the Products in Opportunity Line Item is Blocked, we should not
        //allow the Opportunity to Update or proceed to next stage until it is deleted
        //Or Unblocked from SAP and Shows the Error Message
        OppQuoteMaterialBlockService.validateOnInsertAndUpdate(Trigger.new, Trigger.oldMap);
        
    } 
  
}