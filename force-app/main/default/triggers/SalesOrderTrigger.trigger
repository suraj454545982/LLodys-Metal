trigger SalesOrderTrigger on Order (before insert, after insert, before update, after update) {
    
    //Bypassing
    if (Test.isRunningTest() && TriggerBypassUtil.bypassAll) {
        return;
    }
    
    //Product Blocking Functionality
    if(Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)){
        
        if (Test.isRunningTest()) {
            return;
        }
        MaterialBlockValidationService.validate(Trigger.new, Trigger.oldMap);
    }
    
    if (Trigger.isBefore && Trigger.isUpdate) {
        SalesOrderTriggerHandler.validateApprovalQuantities(Trigger.new, Trigger.oldMap);
        SalesOrderTriggerHandler.freezeApprovedOrder(Trigger.new,Trigger.oldMap);
    }
    
    if (Trigger.isAfter && Trigger.isInsert) {
        SalesOrderTriggerHandler.mapContractToSalesOrder(Trigger.new);
    }
    
    // After update - SAP outbound Insert to SAP logic
    if (Trigger.isAfter && Trigger.isUpdate) {
        System.debug('Triggering');
        SalesOrderTriggerHelper.processSAPSync(Trigger.new, Trigger.oldMap);
    }
}