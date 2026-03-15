Trigger PurchaseOrderLineItemTrigger on Purchase_Order_Line_Item__c (
    before insert, 
    before update,
    before delete,
    after insert, 
    after update, 
    after delete, 
    after undelete
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            PurchaseOrderLineItemTriggerHandler.beforeInsert(Trigger.new);
        }

        if (Trigger.isUpdate) {
            PurchaseOrderLineItemTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
        
        if (Trigger.isUpdate || Trigger.isDelete) {
            MaterialBlockLineItemService.preventLineItemChanges(Trigger.new, Trigger.oldMap);
        }
    }
    
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            PurchaseOrderLineItemTriggerHandler.afterInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            PurchaseOrderLineItemTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
        }
        if (Trigger.isDelete) {
            PurchaseOrderLineItemTriggerHandler.afterDelete(Trigger.old);
        }
        if (Trigger.isUndelete) {
            PurchaseOrderLineItemTriggerHandler.afterUndelete(Trigger.new);
        }
    }
}