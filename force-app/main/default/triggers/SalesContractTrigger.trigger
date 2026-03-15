/**
* @description Trigger on Contract object to handle creation and approval validations.
* Calls mapPOToSalesContract to create Sales Contract Line Items on insert and
* @author Simon Christopher
* @date 2025-09-10
*/
trigger SalesContractTrigger on Contract (before insert, after insert, before update, after update) {
    
    //Bypassing
    if (Test.isRunningTest() && TriggerBypassUtil.bypassAll) {
        return;
    }
    
    // ──────────────────────────────────────────────────
    // BEFORE
    // ──────────────────────────────────────────────────
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            MaterialBlockValidationService.validate(Trigger.new, Trigger.oldMap);
        }
       
        
        if (Trigger.isUpdate) {
            // ← NEW: Prevent re-activating Rejected contracts
            SalesContractTriggerHandler.preventReactivatingRejectedContracts(Trigger.new, Trigger.oldMap);
            
            // NEW: Freeze Approved Contract (except 2 fields)
            SalesContractTriggerHandler.freezeApprovedContract(Trigger.new, Trigger.oldMap);
        }
    }
    
    
    
    // ──────────────────────────────────────────────────
    // AFTER INSERT → create line items (1 Contract per PO)
    // ──────────────────────────────────────────────────
    if (Trigger.isAfter && Trigger.isInsert) {
        SalesContractTriggerHandler.mapPOToSalesContract(Trigger.new);
    }
    
    // ──────────────────────────────────────────────────
    // AFTER UPDATE → SAP sync
    // ──────────────────────────────────────────────────
    if (Trigger.isAfter && Trigger.isUpdate) {
        SalesContractTriggerHelper.processSAPSync(Trigger.new, Trigger.oldMap);
    }
}