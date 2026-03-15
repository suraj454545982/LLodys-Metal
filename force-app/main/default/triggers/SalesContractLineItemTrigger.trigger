/**
* @description Trigger on Sales_Contract_Line_Item__c to handle insertions, updates, and deletions.
* Populates List_Price__c and Amount__c on insert, validates Quantity__c and recalculates Amount__c on update,
* and rolls up CGST, SGST, IGST to Contract on insert, update, and delete.
* @author Simon Christopher P
* @date 2025-09-09
*/
trigger SalesContractLineItemTrigger on Sales_Contract_Line_Item__c (before insert, before update,before delete, after insert, after update, after delete) {
    
    
    // Helper method to collect Contract IDs
    private static Set<Id> collectContractIds(List<Sales_Contract_Line_Item__c> lines) {
        Set<Id> contractIds = new Set<Id>();
        for (Sales_Contract_Line_Item__c cli : lines) {
            if (cli.Contract__c != null) {
                contractIds.add(cli.Contract__c);
            }
        }
        return contractIds;
    }
    
    //Bypassing
    if (Test.isRunningTest() && TriggerBypassUtil.bypassAll) {
        return;
    }
    
    if (Trigger.isBefore && Trigger.isInsert) {
        SalesContractLineItemTriggerHandler.populateListPrice(Trigger.new);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        SalesContractLineItemTriggerHandler.recalculateAmountAndValidateLimit(Trigger.new, Trigger.oldMap);
        SalesContractLineItemTriggerHandler.validatePriceBookPlant(Trigger.new);
    }
    
    /**
     * Before SAP sync → Reason_for_Rejection__c MUST be blank
     * After SAP sync → user CAN fill or edit it freely
     */
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        SalesContractLineItemTriggerHandler.preventRejectionReasonBeforeSAPSync(
            Trigger.new,
            Trigger.isUpdate ? Trigger.oldMap : null
        );
    }
    
    if(Trigger.isBefore && Trigger.isUpdate){
        //When line is blocked → only allow editing Reason_for_Rejection__c
        SalesContractLineItemTriggerHandler.preventEditOnBlockedLineItems(Trigger.new, Trigger.oldMap);
        
        // NEW: Block edit when parent Contract is Approved
        SalesContractLineItemTriggerHandler.preventEditOnApprovedContractLineItems(Trigger.new, Trigger.oldMap);
    }
    
    if (Trigger.isBefore && (Trigger.isUpdate || Trigger.isDelete)) {
        MaterialBlockLineItemService.preventLineItemChanges(Trigger.new, Trigger.oldMap);
    }
    
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate || Trigger.isDelete)) {
        Set<Id> contractIds = collectContractIds(Trigger.isDelete ? Trigger.old : Trigger.new);
        if (!contractIds.isEmpty()) {
            SalesContractLineItemTriggerHandler.rollupTaxOnContract(contractIds);
        }
    }
    
    //SAP Triggering - Update logic to SAP
    if (Trigger.isAfter && Trigger.isUpdate) {
        SalesContractLineItemHelper.processLineItemChange(Trigger.new, Trigger.oldMap);
    }
    
    
}