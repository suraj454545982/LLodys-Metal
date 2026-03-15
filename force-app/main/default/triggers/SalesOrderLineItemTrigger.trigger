/**
 * @description Trigger on OrderItem to handle quantity updates, auto-calculation of TotalPrice,
 * and rollup of CGST, SGST, IGST, Freight, Packing and Forwarding, Shipping and Handling,
 * Other Expenses, and Discount to parent Order. Validates quantities against remaining Sales
 * Contract limits and ensures PricebookEntryId and UnitPrice are populated for manual insertions.
 * @author Simon Christopher P
 * @date 2025-09-09
 */
trigger SalesOrderLineItemTrigger on OrderItem (before insert, before update,before delete, after insert, after update, after delete) {
    // Helper method to collect Order IDs
    private static Set<Id> collectOrderIds(List<OrderItem> lines) {
        Set<Id> orderIds = new Set<Id>();
        for (OrderItem li : lines) {
            if (li.OrderId != null) {
                orderIds.add(li.OrderId);
            }
        }
        return orderIds;
    }
    
    if (Trigger.isBefore && Trigger.isInsert) {
        OrderItemTriggerHandler.populateListPrice(Trigger.new);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        OrderItemTriggerHandler.recalculateTotalPriceAndValidateLimit(Trigger.new, Trigger.oldMap);
    }
    
    if (Trigger.isBefore && (Trigger.isUpdate || Trigger.isDelete)) {
        MaterialBlockLineItemService.preventLineItemChanges(Trigger.new, Trigger.oldMap);
    }
    
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate || Trigger.isDelete)) {
        Set<Id> orderIds = collectOrderIds(Trigger.isDelete ? Trigger.old : Trigger.new);
        if (!orderIds.isEmpty()) {
            OrderItemTriggerHandler.rollupOnOrder(orderIds);
        }
    }
    
    //SAP Triggering - Update logic to SAP
    if (Trigger.isAfter && Trigger.isUpdate) {
        SalesOrderLineItemHelper.processLineItemChange(Trigger.new, Trigger.oldMap);
    }
}