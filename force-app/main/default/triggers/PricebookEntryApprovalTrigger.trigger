trigger PricebookEntryApprovalTrigger on PricebookEntryApproval__c (before insert, before update, after insert, after update, before delete, after delete, after undelete) {

      if (Trigger.isBefore) {
        if (Trigger.isUpdate) {
            PricebookEntryApprovalHandler.validatePBRejectComments(Trigger.new, Trigger.oldMap);
           
        }
      }
     
   
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
        
            PricebookEntryApprovalHandler.handleAfterInsert(Trigger.new);
            PricebookEntryApprovalHandler.insertApprove(Trigger.new);
        }
        if (Trigger.isUpdate) {
         
            PricebookEntryApprovalHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
            PricebookEntryApprovalHandler.updateApprove(Trigger.new, Trigger.oldMap);
            
        }	
    }
}