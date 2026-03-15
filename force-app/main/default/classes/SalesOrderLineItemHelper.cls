public class SalesOrderLineItemHelper {

    // --- Called from Trigger ---
    public static void processLineItemChange(List<OrderItem> newList, Map<Id, OrderItem> oldMap) {
        Set<Id> orderIdsToUpdate = fetchSAPUpdateIds(newList, oldMap);

        if (!orderIdsToUpdate.isEmpty()) {
            System.debug('Sales Order Line Items triggered SAP Update for Orders: ' + orderIdsToUpdate);
            Database.executeBatch(new SalesOrderUpdateOutboundCalloutToSAP(orderIdsToUpdate), 50);
        }
    }

    // --- Fetch Order IDs that require SAP Update ---
    public static Set<Id> fetchSAPUpdateIds(List<OrderItem> newList, Map<Id, OrderItem> oldMap) {
        Set<Id> orderIdsToUpdate = new Set<Id>();
        Set<Id> orderIds = new Set<Id>();

        // Step 1: Collect all related Orders
        for (OrderItem oli : newList) {
            if (oli.OrderId != null) {
                orderIds.add(oli.OrderId);
            }
        }

        // Step 2: Query parent Orders and related Contracts (bulk safe)
        Map<Id, Order> orderMap = new Map<Id, Order>(
            [SELECT Id, SAP_Sales_Order_Number__c, ContractId,
                    Contract.SAP_Sales_Contract_Number__c
             FROM Order
             WHERE Id IN :orderIds]
        );

        // Step 3: Loop through line items and detect rejection changes
        for (OrderItem oli : newList) {
            OrderItem oldOli = oldMap.get(oli.Id);

            if (oli.OrderId == null) continue;

            Order parentOrder = orderMap.get(oli.OrderId);

            // Skip if parent Order or Contract not yet in SAP
            if (parentOrder == null ||
                parentOrder.SAP_Sales_Order_Number__c == null ||
                parentOrder.Contract == null ||
                parentOrder.Contract.SAP_Sales_Contract_Number__c == null) {
                continue;
            }

            // Step 4: Check if Reason for Rejection or Plant or Qty changed
            if (oli.Reason_for_Rejection__c != oldOli.Reason_for_Rejection__c || oli.Quantity != oldOli.Quantity || oli.Plant__c != oldOli.Plant__c) {
                orderIdsToUpdate.add(oli.OrderId);
            }
        }

        return orderIdsToUpdate;
    }
}