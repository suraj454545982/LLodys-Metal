Public with sharing class PurchaseOrderLineItemTriggerHandler {

    /**
     * Before Insert Event
     * Add before-insert logic here
     */
    public static void beforeInsert(List<Purchase_Order_Line_Item__c> newList) {
        PurchaseOrderLineItemHelper.populateSalesPrice(newList);
    }

    /**
     * Before Update Event
     * Add before-update logic here
     */
    public static void beforeUpdate(List<Purchase_Order_Line_Item__c> newList, Map<Id, Purchase_Order_Line_Item__c> oldMap) {
        PurchaseOrderLineItemHelper.recalculateTotalAndValidateLimit(newList, oldMap);
    }

    /**
     * After Insert Event
     * Add after-insert logic here
     */
    public static void afterInsert(List<Purchase_Order_Line_Item__c> newList) {
        Set<Id> poIds = PurchaseOrderLineItemHelper.collectPoIds(newList);
        PurchaseOrderLineItemHelper.updatePurchaseOrderTotals(poIds);
    }

    /**
     * After Update Event
     * Add after-update logic here
     */
    public static void afterUpdate(List<Purchase_Order_Line_Item__c> newList, Map<Id, Purchase_Order_Line_Item__c> oldMap) {
        Set<Id> poIds = PurchaseOrderLineItemHelper.collectPoIds(newList);
        PurchaseOrderLineItemHelper.updatePurchaseOrderTotals(poIds);
    }

    /**
     * After Delete Event
     * Add after-delete logic here
     */
    public static void afterDelete(List<Purchase_Order_Line_Item__c> oldList) {
        Set<Id> poIds = PurchaseOrderLineItemHelper.collectPoIds(oldList);
        PurchaseOrderLineItemHelper.updatePurchaseOrderTotals(poIds);
    }

    /**
     * After Undelete Event
     * Add after-undelete logic here
     */
    public static void afterUndelete(List<Purchase_Order_Line_Item__c> newList) {
        Set<Id> poIds = PurchaseOrderLineItemHelper.collectPoIds(newList);
        PurchaseOrderLineItemHelper.updatePurchaseOrderTotals(poIds);
    }
}