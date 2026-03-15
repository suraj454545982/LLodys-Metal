trigger ProformaInvoice on Proforma_invoice__c (before insert,before update,after insert, after update) {
 
    //Bypassing
    if (Test.isRunningTest() && TriggerBypassUtil.bypassAll) {
        return;
    }
    
    
    //Product Blocking Functionality
    if(Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)){
            MaterialBlockValidationService.validate(Trigger.new, Trigger.oldMap);
    }
    
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
           ProformaInvoiceHandler.handleBeforeInsert(Trigger.new);
            ProformaInvoiceHandlerNew.preventDuplicateDraftPI(Trigger.new);
            
           // Validate PO has remaining qty before creating PI
       ProformaInvoiceHandlerNew.validateRemainingQty(Trigger.new);
         
            
        }
        if (Trigger.isUpdate) {
           ProformaInvoiceHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
           ProformaInvoiceHandlerNew.validateApprovalQuantities(Trigger.new);
        }
    }
    
     if (Trigger.isAfter && Trigger.isInsert) {
        // Create PI Line Items after PI is created
        ProformaInvoiceHandlerNew.mapPOtoPI(Trigger.new);
    }
    
     
    
    
}