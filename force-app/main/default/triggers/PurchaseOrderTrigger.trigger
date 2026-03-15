Trigger PurchaseOrderTrigger on Purchase_Order__c ( before insert, before update, after insert, after update, before delete, after delete, after undelete) {

	//Bypassing
    if (Test.isRunningTest() && TriggerBypassUtil.bypassAll) {
        return;
    }
    
    //Product Blocking Functionality
    if(Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)){
            MaterialBlockValidationService.validate(Trigger.new, Trigger.oldMap);
    }
    
    if (Trigger.isAfter && Trigger.isInsert) {
        PurchaseOrderTriggerHandler.afterInsert(Trigger.new);
    }
    if (Trigger.isUpdate && Trigger.isBefore){
        PurchaseOrderTriggerHandler.beforeUpdate(Trigger.new,Trigger.oldMap); 
    }
}