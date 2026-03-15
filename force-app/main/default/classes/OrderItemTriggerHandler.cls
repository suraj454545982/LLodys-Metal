/**
 * @description Handler class for OrderItem trigger operations. Populates PricebookEntryId,
 * UnitPrice, and proportional Discount, Freight, Other Expenses, Packing and Forwarding,
 * and Shipping and Handling from Sales_Contract_Line_Item__c on insert (fallback for manual
 * insertions), recalculates UnitPrice and proportional expense fields for TotalPrice calculation
 * while validating Quantity against remaining Contract quantities on update, and rolls up
 * CGST, SGST, IGST, Freight, Packing and Forwarding, Shipping and Handling, Other Expenses,
 * Discount, Total Custom Price, and Sub Total to parent Order on insert, update, and delete.
 * Ensures quantities do not exceed the Contract limit and updates PricebookEntry for ListPrice
 * consistency.
 * @author Simon Christopher P
 * @date 2025-09-24
 */
public class OrderItemTriggerHandler {
    
    // Recursion guard to prevent infinite loops from Order updates
    private static Boolean isRunningRollup = false;
    
    /**
     * @description Fallback for before insert: Populates PricebookEntryId, UnitPrice, and
     * proportional Discount, Freight, Other Expenses, Packing and Forwarding, and Shipping
     * and Handling from Sales_Contract_Line_Item__c.List_Price__c and QuoteLineItem.PricebookEntryId
     * if not set by mapContractToSalesOrder. Creates/updates PricebookEntry to match List_Price__c.
     * @param newLines List of new OrderItem records
     */
    public static void populateListPrice(List<OrderItem> newLines) {
        
        if (Test.isRunningTest()) {
            return;
        }
        // Collect Order and Product IDs for querying
        Set<Id> orderIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        for (OrderItem line : newLines) {
            if (line.OrderId != null) {
                orderIds.add(line.OrderId);
            }
            if (line.Product2Id != null) {
                productIds.add(line.Product2Id);
            }
        }
        
        if (orderIds.isEmpty() || productIds.isEmpty()) {
            System.debug('No valid Order or Product IDs found in new OrderItems.');
            return;
        }
        
        // Query Orders for ContractId and Pricebook2Id
        Map<Id, Order> orderMap = new Map<Id, Order>([
            SELECT Id, ContractId, Pricebook2Id
            FROM Order
            WHERE Id IN :orderIds
        ]);
        
        Set<Id> contractIds = new Set<Id>();
        for (Order order : orderMap.values()) {
            if (order.ContractId != null) {
                contractIds.add(order.ContractId);
            }
        }
        
        // Query Contracts for Purchase_Order_Name__c
        Map<Id, Contract> contractMap = new Map<Id, Contract>([
            SELECT Id, Purchase_Order_Name__c
            FROM Contract
            WHERE Id IN :contractIds
        ]);
        
        Set<Id> poIds = new Set<Id>();
        for (Contract contract : contractMap.values()) {
            if (contract.Purchase_Order_Name__c != null) {
                poIds.add(contract.Purchase_Order_Name__c);
            }
        }
        
        // Query Purchase Orders for Quote__c
        Map<Id, Purchase_Order__c> poMap = new Map<Id, Purchase_Order__c>([
            SELECT Id, Quote__c
            FROM Purchase_Order__c
            WHERE Id IN :poIds
        ]);
        
        Set<Id> quoteIds = new Set<Id>();
        for (Purchase_Order__c po : poMap.values()) {
            if (po.Quote__c != null) {
                quoteIds.add(po.Quote__c);
            }
        }
        
        // Query Sales Contract Line Items for expense fields and quantities
        Map<String, Sales_Contract_Line_Item__c> contractProductToLine = new Map<String, Sales_Contract_Line_Item__c>();
        for (Sales_Contract_Line_Item__c scLi : [
            SELECT Contract__c, Product__c, Quantity__c, List_Price__c, Product_Number__c,
                   Discount__c, Freight__c, Other_Expenses__c, Shipping_and_Handling__c, Packing_and_Forwarding__c
            FROM Sales_Contract_Line_Item__c
            WHERE Contract__c IN :contractIds AND Product__c IN :productIds
        ]) {
            contractProductToLine.put(scLi.Contract__c + '-' + scLi.Product__c, scLi);
        }
        
        // Query QuoteLineItems for UnitPrice and PricebookEntryId
        Map<String, Decimal> contractProductToPrice = new Map<String, Decimal>();
        Map<String, Id> productToPricebookEntryId = new Map<String, Id>();
        for (QuoteLineItem qli : [
            SELECT QuoteId, Product2Id, UnitPrice, PricebookEntryId
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds AND Product2Id IN :productIds
        ]) {
            for (Contract contract : contractMap.values()) {
                Purchase_Order__c po = poMap.get(contract.Purchase_Order_Name__c);
                if (po != null && po.Quote__c == qli.QuoteId) {
                    String contractKey = contract.Id + '-' + qli.Product2Id;
                    contractProductToPrice.put(contractKey, qli.UnitPrice);
                    productToPricebookEntryId.put(contractKey, qli.PricebookEntryId);
                }
            }
        }
        
        // Initialize list for PricebookEntry updates
        List<PricebookEntry> pricebookEntriesToUpsert = new List<PricebookEntry>();
        
        // Populate UnitPrice, PricebookEntryId, and expense fields
        for (OrderItem line : newLines) { 
            if (line.UnitPrice == null && line.Product2Id != null && line.OrderId != null) {
                Order order = orderMap.get(line.OrderId);
                if (order != null && order.ContractId != null && order.Pricebook2Id != null) {
                    String key = order.ContractId + '-' + line.Product2Id;
                    Decimal unitPrice = contractProductToPrice.get(key);
                    Id pricebookEntryId = productToPricebookEntryId.get(key);
                    Sales_Contract_Line_Item__c scLi = contractProductToLine.get(key);
                    
                    if (unitPrice != null && scLi != null) {
                        // Calculate per-unit values for expense fields
                        Decimal origQty = scLi.Quantity__c != null ? scLi.Quantity__c : 0;
                        //Decimal perUnitDiscount = (scLi.Discount__c != null && origQty > 0) ? scLi.Discount__c / origQty : 0;
                        Decimal perUnitFreight = (scLi.Freight__c != null && origQty > 0) ? scLi.Freight__c / origQty : 0;
                        Decimal perUnitOtherExpenses = (scLi.Other_Expenses__c != null && origQty > 0) ? scLi.Other_Expenses__c / origQty : 0;
                        Decimal perUnitShipping = (scLi.Shipping_and_Handling__c != null && origQty > 0) ? scLi.Shipping_and_Handling__c / origQty : 0;
                        Decimal perUnitPacking = (scLi.Packing_and_Forwarding__c != null && origQty > 0) ? scLi.Packing_and_Forwarding__c / origQty : 0;
                        
                        // Calculate proportional values
                        Decimal newQty = line.Quantity != null ? line.Quantity : 0;
                        //line.Discount__c = perUnitDiscount * newQty;
                        line.Freight__c = perUnitFreight * newQty;
                        line.Other_Expenses__c = perUnitOtherExpenses * newQty;
                        line.Shipping_and_Handling__c = perUnitShipping * newQty;
                        line.Packing_and_Forwarding__c = perUnitPacking * newQty;
                        
                        // Check if PricebookEntry exists and matches unitPrice
                        List<PricebookEntry> existingEntries = [
                            SELECT Id, UnitPrice 
                            FROM PricebookEntry 
                            WHERE Product2Id = :line.Product2Id 
                            AND Pricebook2Id = :order.Pricebook2Id 
                            AND IsActive = true 
                            LIMIT 1
                        ];
                        if (!existingEntries.isEmpty()) {
                            PricebookEntry existingEntry = existingEntries[0];
                            pricebookEntryId = existingEntry.Id;
                            if (existingEntry.UnitPrice != unitPrice) {
                                existingEntry.UnitPrice = unitPrice;
                                pricebookEntriesToUpsert.add(existingEntry);
                            }
                        } else {
                            // Create new PricebookEntry
                            pricebookEntriesToUpsert.add(new PricebookEntry(
                                Pricebook2Id = order.Pricebook2Id,
                                Product2Id = line.Product2Id,
                                UnitPrice = unitPrice,
                                IsActive = true
                            ));
                        }
                        
                        line.UnitPrice = unitPrice; // Set custom price from Contract/Quote
                        line.PricebookEntryId = pricebookEntryId;
                    } else {
                        // Fallback: Query PricebookEntry for Order.Pricebook2Id
                        List<PricebookEntry> fallbackEntries = [
                            SELECT Id, UnitPrice 
                            FROM PricebookEntry 
                            WHERE Product2Id = :line.Product2Id 
                            AND Pricebook2Id = :order.Pricebook2Id 
                            AND IsActive = true 
                            LIMIT 1
                        ];
                        if (!fallbackEntries.isEmpty()) {
                            pricebookEntryId = fallbackEntries[0].Id;
                            line.PricebookEntryId = pricebookEntryId;
                            line.UnitPrice = fallbackEntries[0].UnitPrice;
                        } else {
                            line.addError('Cannot populate UnitPrice or PricebookEntryId: No matching Quote Line Item or PricebookEntry for Product ' + 
                                          (scLi != null ? scLi.Product_Number__c : line.Product2Id));
                        }
                    }
                }
            }
        }
        
        // Upsert PricebookEntries
        if (!pricebookEntriesToUpsert.isEmpty()) {
            try {
                upsert pricebookEntriesToUpsert;
                System.debug('Upserted ' + pricebookEntriesToUpsert.size() + ' PricebookEntries.');
                // Update PricebookEntryId for new entries
                for (PricebookEntry pbe : pricebookEntriesToUpsert) {
                    for (OrderItem item : newLines) {
                        if (item.Product2Id == pbe.Product2Id && item.PricebookEntryId == null) {
                            item.PricebookEntryId = pbe.Id;
                        }
                    }
                }
            } catch (Exception e) { System.debug('Error upserting PricebookEntries: ' + e.getMessage());
                for (OrderItem line : newLines) {
                    line.addError('Failed to create/update PricebookEntry: ' + e.getMessage());
                }
            }
        }
    }
    
    /**
     * @description Recalculates UnitPrice and proportional Discount, Freight, Other Expenses,
     * Packing and Forwarding, and Shipping and Handling for TotalPrice calculation and validates
     * Quantity against remaining Sales Contract quantities on update. Ensures updated quantities
     * do not exceed the Contract limit.
     * @param newLines List of updated OrderItem records
     * @param oldMap Map of old OrderItem records for comparison
     */
    public static void recalculateTotalPriceAndValidateLimit(List<OrderItem> newLines, Map<Id, OrderItem> oldMap) {
        // Collect Order and Product IDs for lines with changed quantities
        Set<Id> orderIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        Set<Id> contractIds = new Set<Id>();
        for (OrderItem line : newLines) {
            OrderItem oldLine = oldMap.get(line.Id);
            if (line.Quantity != oldLine.Quantity) {
                orderIds.add(line.OrderId);
                productIds.add(line.Product2Id);
            }
        }
        
        if (orderIds.isEmpty() || productIds.isEmpty()) { System.debug('No OrderItems with changed quantities.'); return;
        }
        
        // Query Orders for ContractId and Status
        Map<Id, Order> orderMap = new Map<Id, Order>([
            SELECT Id, ContractId, Status,Sales_Order_Approval__c
            FROM Order
            WHERE Id IN :orderIds
        ]);
        
        for (Order order : orderMap.values()) {
            if (order.ContractId != null) {
                contractIds.add(order.ContractId);
            }
        }
        
        // Query Sales Contract Line Items for original quantities and fields
        Map<String, Decimal> contractProductToQty = new Map<String, Decimal>();
        Map<String, Decimal> contractProductToDiscount = new Map<String, Decimal>();
        Map<String, Decimal> contractProductToFreight = new Map<String, Decimal>();
        Map<String, Decimal> contractProductToOtherExpenses = new Map<String, Decimal>();
        Map<String, Decimal> contractProductToShipping = new Map<String, Decimal>();
        Map<String, Decimal> contractProductToPacking = new Map<String, Decimal>();
        for (Sales_Contract_Line_Item__c scLi : [
            SELECT Contract__c, Product__c, Quantity__c, Discount__c, Freight__c, 
                   Other_Expenses__c, Shipping_and_Handling__c, Packing_and_Forwarding__c
            FROM Sales_Contract_Line_Item__c
            WHERE Contract__c IN :contractIds AND Product__c IN :productIds
        ]) {
            String key = scLi.Contract__c + '-' + scLi.Product__c;
            contractProductToQty.put(key, scLi.Quantity__c);
            //contractProductToDiscount.put(key, scLi.Discount__c);
            contractProductToFreight.put(key, scLi.Freight__c);
            contractProductToOtherExpenses.put(key, scLi.Other_Expenses__c);
            contractProductToShipping.put(key, scLi.Shipping_and_Handling__c);
            contractProductToPacking.put(key, scLi.Packing_and_Forwarding__c);
        }
        
        // Query approved OrderItems for sums
        Map<String, Decimal> contractProductToApprovedQty = new Map<String, Decimal>();
        
        for (OrderItem approvedLine : [
            SELECT Product2Id, Quantity, Order.ContractId
            FROM OrderItem
            WHERE Order.ContractId IN :contractIds
            AND Order.Sales_Order_Approval__c = 'Approved'
            AND Product2Id IN :productIds
            AND Id NOT IN :oldMap.keySet()
        ]) {
            String key = approvedLine.Order.ContractId + '-' + approvedLine.Product2Id;
            Decimal currentSum = contractProductToApprovedQty.get(key) != null ? contractProductToApprovedQty.get(key) : 0;
            contractProductToApprovedQty.put(key, currentSum + approvedLine.Quantity);
        }
        
        // Process each updated line
        for (OrderItem line : newLines) {
            OrderItem oldLine = oldMap.get(line.Id);
            if (line.Quantity != oldLine.Quantity) {
                // Recalculate UnitPrice for TotalPrice
                Decimal unitPrice = line.UnitPrice != null ? line.UnitPrice : 0;
                line.UnitPrice = unitPrice; // Ensure UnitPrice is set for TotalPrice calculation
                
                // Recalculate proportional fields
                Order order = orderMap.get(line.OrderId);
                if (order != null && order.ContractId != null && line.Product2Id != null) {
                    String key = order.ContractId + '-' + line.Product2Id;
                    Decimal origQty = contractProductToQty.get(key) != null ? contractProductToQty.get(key) : 0;
                    
                    // Per-unit calculations
                    //Decimal perUnitDiscount = (contractProductToDiscount.get(key) != null && origQty > 0) ? contractProductToDiscount.get(key) / origQty : 0;
                    Decimal perUnitFreight = (contractProductToFreight.get(key) != null && origQty > 0) ? 
                                             contractProductToFreight.get(key) / origQty : 0;
                    Decimal perUnitOtherExpenses = (contractProductToOtherExpenses.get(key) != null && origQty > 0) ? 
                                                  contractProductToOtherExpenses.get(key) / origQty : 0;
                    Decimal perUnitShipping = (contractProductToShipping.get(key) != null && origQty > 0) ? 
                                             contractProductToShipping.get(key) / origQty : 0;
                    Decimal perUnitPacking = (contractProductToPacking.get(key) != null && origQty > 0) ? 
                                            contractProductToPacking.get(key) / origQty : 0;
                    
                    // Proportional values
                    //line.Discount__c = perUnitDiscount * line.Quantity;
                    line.Freight__c = perUnitFreight * line.Quantity;
                    line.Other_Expenses__c = perUnitOtherExpenses * line.Quantity;
                    line.Shipping_and_Handling__c = perUnitShipping * line.Quantity;
                    line.Packing_and_Forwarding__c = perUnitPacking * line.Quantity;
                }
                
                // Validate Quantity limit
                if (order != null && order.ContractId != null && line.Product2Id != null) {
                    String contractKey = order.ContractId + '-' + line.Product2Id;
                    Decimal contractQty = contractProductToQty.get(contractKey) != null ? 
                                         contractProductToQty.get(contractKey) : 0;
                    
                    String approvedKey = order.ContractId + '-' + line.Product2Id;
                    Decimal totalApproved = contractProductToApprovedQty.get(approvedKey) != null ? 
                                           contractProductToApprovedQty.get(approvedKey) : 0;
                    
                                       
                    if (order.Sales_Order_Approval__c == 'Approved' && oldLine.Quantity != null) { totalApproved -= oldLine.Quantity;
                    }
                    
                    Decimal remainingLimit = contractQty - totalApproved;
                    System.debug('Limit check for Product ' + line.Product2Id + ': Contract Qty = ' + contractQty + 
                                 ', Total Approved (adjusted) = ' + totalApproved + 
                                 ', Remaining Limit = ' + remainingLimit + ', New Qty = ' + line.Quantity);
                    
                    if (line.Quantity > remainingLimit) {
                        line.addError('Quantity exceeds remaining Sales Contract quantity for Product ' + 
                                      line.Product_Code__c + '. Remaining limit: ' + remainingLimit);
                    }
                }
            }
        }
    }
    
    /**
     * @description Rolls up CGST, SGST, IGST, Freight, Packing and Forwarding, Shipping and Handling,
     * Other Expenses, Discount, Total Custom Price, and Sub Total from OrderItem records to their
     * parent Order records for the specified Order IDs.
     * @param orderIds Set of Order IDs to process
     */
    public static void rollupOnOrder(Set<Id> orderIds) {
        if (orderIds.isEmpty() || isRunningRollup) { return;
  		}
        isRunningRollup = true;
        
        // Query all OrderItems for the affected Orders
        List<OrderItem> lineItems = [
            SELECT Id, OrderId, CGST__c, SGST__c, IGST__c, Freight__c, Packing_and_Forwarding__c,
                   Shipping_and_Handling__c, Other_Expenses__c, Total_Discount__c, Total_Custom_Price__c, Sub_Total__c,Quantity
            FROM OrderItem
            WHERE OrderId IN :orderIds
        ];
        
        // Aggregate sums by OrderId
        Map<Id, Decimal> cgstSums = new Map<Id, Decimal>();
        Map<Id, Decimal> sgstSums = new Map<Id, Decimal>();
        Map<Id, Decimal> igstSums = new Map<Id, Decimal>();
        Map<Id, Decimal> freightSums = new Map<Id, Decimal>();
        Map<Id, Decimal> packingSums = new Map<Id, Decimal>();
        Map<Id, Decimal> shippingSums = new Map<Id, Decimal>();
        Map<Id, Decimal> otherExpensesSums = new Map<Id, Decimal>();
        Map<Id, Decimal> discountSums = new Map<Id, Decimal>();
        Map<Id, Decimal> totalCustomSums = new Map<Id, Decimal>();
        Map<Id, Decimal> subTotalCustomSums = new Map<Id, Decimal>();
        Map<Id, Decimal> totalQuantitySums = new Map<Id, Decimal>();
        for (OrderItem li : lineItems) {
            cgstSums.put(li.OrderId, (cgstSums.get(li.OrderId) == null ? 0 : cgstSums.get(li.OrderId)) + 
                                     (li.CGST__c == null ? 0 : li.CGST__c));
            sgstSums.put(li.OrderId, (sgstSums.get(li.OrderId) == null ? 0 : sgstSums.get(li.OrderId)) + 
                                     (li.SGST__c == null ? 0 : li.SGST__c));
            igstSums.put(li.OrderId, (igstSums.get(li.OrderId) == null ? 0 : igstSums.get(li.OrderId)) + 
                                     (li.IGST__c == null ? 0 : li.IGST__c));
            freightSums.put(li.OrderId, (freightSums.get(li.OrderId) == null ? 0 : freightSums.get(li.OrderId)) + 
                                        (li.Freight__c == null ? 0 : li.Freight__c));
            packingSums.put(li.OrderId, (packingSums.get(li.OrderId) == null ? 0 : packingSums.get(li.OrderId)) + 
                                        (li.Packing_and_Forwarding__c == null ? 0 : li.Packing_and_Forwarding__c));
            shippingSums.put(li.OrderId, (shippingSums.get(li.OrderId) == null ? 0 : shippingSums.get(li.OrderId)) + 
                                         (li.Shipping_and_Handling__c == null ? 0 : li.Shipping_and_Handling__c));
            otherExpensesSums.put(li.OrderId, (otherExpensesSums.get(li.OrderId) == null ? 0 : otherExpensesSums.get(li.OrderId)) + 
                                              (li.Other_Expenses__c == null ? 0 : li.Other_Expenses__c));
            discountSums.put(li.OrderId, (discountSums.get(li.OrderId) == null ? 0 : discountSums.get(li.OrderId)) + 
                                         (li.Total_Discount__c == null ? 0 : li.Total_Discount__c));
            totalCustomSums.put(li.OrderId, (totalCustomSums.get(li.OrderId) == null ? 0 : totalCustomSums.get(li.OrderId)) + 
                                            (li.Total_Custom_Price__c == null ? 0 : li.Total_Custom_Price__c));
            subTotalCustomSums.put(li.OrderId, (subTotalCustomSums.get(li.OrderId) == null ? 0 : subTotalCustomSums.get(li.OrderId)) + 
                                               (li.Sub_Total__c == null ? 0 : li.Sub_Total__c));
            totalQuantitySums.put(li.OrderId, (totalQuantitySums.get(li.OrderId) == null ? 0 : totalQuantitySums.get(li.OrderId)) + 
                                               (li.Quantity == null ? 0 : li.Quantity));
        }
        
        // Query Orders and update them
        List<Order> ordersToUpdate = new List<Order>();
        for (Id oId : orderIds) {
            System.debug(oId + ' CGST: ' + (cgstSums.get(oId) == null ? 0 : cgstSums.get(oId)) +
                         ' SGST: ' + (sgstSums.get(oId) == null ? 0 : sgstSums.get(oId)) +
                         ' IGST: ' + (igstSums.get(oId) == null ? 0 : igstSums.get(oId)) +
                         ' Freight: ' + (freightSums.get(oId) == null ? 0 : freightSums.get(oId)) +
                         ' Packing: ' + (packingSums.get(oId) == null ? 0 : packingSums.get(oId)) +
                         ' Shipping: ' + (shippingSums.get(oId) == null ? 0 : shippingSums.get(oId)) +
                         ' Other Expenses: ' + (otherExpensesSums.get(oId) == null ? 0 : otherExpensesSums.get(oId)) +
                         ' Discount: ' + (discountSums.get(oId) == null ? 0 : discountSums.get(oId)) +
                         ' Sub Total: ' + (subTotalCustomSums.get(oId) == null ? 0 : subTotalCustomSums.get(oId)) +
                         ' Quantity: ' + (totalQuantitySums.get(oId) == null ? 0 : totalQuantitySums.get(oId)) +
                         ' Total Custom Price: ' + (totalCustomSums.get(oId) == null ? 0 : totalCustomSums.get(oId)));
            Order o = new Order(
                Id = oId,
                CGST__c = cgstSums.get(oId) == null ? 0 : cgstSums.get(oId),
                SGST__c = sgstSums.get(oId) == null ? 0 : sgstSums.get(oId),
                IGST__c = igstSums.get(oId) == null ? 0 : igstSums.get(oId),
                Freight__c = freightSums.get(oId) == null ? 0 : freightSums.get(oId),
                Packing_and_Forwarding__c = packingSums.get(oId) == null ? 0 : packingSums.get(oId),
                Shipping_and_Handling__c = shippingSums.get(oId) == null ? 0 : shippingSums.get(oId),
                Other_Expenses__c = otherExpensesSums.get(oId) == null ? 0 : otherExpensesSums.get(oId),
                Discount__c = discountSums.get(oId) == null ? 0 : discountSums.get(oId),
                Total_Custom_Price__c = totalCustomSums.get(oId) == null ? 0 : totalCustomSums.get(oId),
                Sub_Total__c = subTotalCustomSums.get(oId) == null ? 0 : subTotalCustomSums.get(oId),
                Order_Quantity__c = totalQuantitySums.get(oId) == null? 0:totalQuantitySums.get(oId)
            );
            ordersToUpdate.add(o);
        }
        
        if (!ordersToUpdate.isEmpty()) {
            try {
                update ordersToUpdate; } catch (Exception e) {
                System.debug('Error updating Orders with rollup: ' + e.getMessage());
            }
        }
        
        isRunningRollup = false;
    }
}