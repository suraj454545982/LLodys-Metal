trigger ProformaInvoiceLineItemTrigger on Proforma_Invoice_Line_Item__c 
(before insert, before update,before delete, after insert, after update, after delete) {

    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            ProformaInvoiceLineItemHandler.handleBeforeInsertUpdate(Trigger.new, Trigger.oldMap);
        }
        
        if (Trigger.isBefore && (Trigger.isUpdate || Trigger.isDelete)) {
            MaterialBlockLineItemService.preventLineItemChanges(Trigger.new, Trigger.oldMap);
        }
    }

    if (Trigger.isAfter) {
        if (Trigger.isInsert  || Trigger.isDelete || Trigger.isUpdate) {
            ProformaInvoiceLineItemHandler.handleAfterInsertUpdateDelete(Trigger.new, Trigger.old);
        }
    }
}