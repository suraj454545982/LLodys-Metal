/**
* @description Handler class for Order trigger operations. Maps Sales Contract Line Items
* to OrderItems, validates Draft Orders, remaining quantities, and approval quantities.
* Ensures Orders are created only for Approved Contracts and handles quantity calculations
* for multiple Orders per Contract. Sets PricebookEntryId and UnitPrice from Sales Contract,
* calculates proportional Discount, Freight, Other Expenses, Packing and Forwarding, and
* Shipping and Handling based on per-unit values from Sales Contract Line Items, and updates
* PricebookEntry for ListPrice consistency.
* @author Simon Christopher P
* @date 2025-09-11
*/
public class SalesOrderTriggerHandler {
    
    // Recursion guard to prevent infinite loops from updates
    //private static Boolean isRunning = false;
    private static Set<Id> processedOrderIds = new Set<Id>();    
    /**
* @description Maps Sales_Contract_Line_Item__c records to OrderItem records for new Orders.
* Validates against Draft Orders, Contract status, and remaining quantities. Auto-populates
* fields including PricebookEntryId, UnitPrice, and proportional Discount, Freight, Other
* Expenses, Packing and Forwarding, and Shipping and Handling from Sales_Contract_Line_Item__c,
* updates PricebookEntry for ListPrice consistency, and sets Order.Pricebook2Id via DML.
* @param newOrderList List of new Order records from trigger context
*/
    public static void mapContractToSalesOrder(List<Order> newOrderList) {
        
        if (!Trigger.isInsert) {
            return;
        }
        
        // Collect Contract Ids, Opportunity Ids, and new Order Ids
        Set<Id> contractIds = new Set<Id>();
        Set<Id> oppIds = new Set<Id>();
        Set<Id> newOrderIds = new Set<Id>();
        for (Order order : newOrderList) {
            if (order.ContractId != null) {
                contractIds.add(order.ContractId);
            }
            if (order.OpportunityId != null) { 
                oppIds.add(order.OpportunityId);
            }
            if (order.Id != null) {
                newOrderIds.add(order.Id);
            }
        }
        
        if (contractIds.isEmpty() || oppIds.isEmpty()) {
            System.debug('No valid Contract or Opportunity Ids found in new Orders.');
            //isRunning = false;
            return;
        }
        
        // Step 1: Validate no existing Draft Orders for the Contracts
        Map<Id, List<Order>> contractToExistingOrdersMap = new Map<Id, List<Order>>();
        List<Order> existingOrders = [
            SELECT Id, ContractId, Status, OrderNumber,Sales_Order_Approval__c
            FROM Order
            WHERE ContractId IN :contractIds
            AND Id NOT IN :newOrderIds
        ];
        for (Order existingOrder : existingOrders) {
            if (!contractToExistingOrdersMap.containsKey(existingOrder.ContractId)) {
                contractToExistingOrdersMap.put(existingOrder.ContractId, new List<Order>());
            }
            contractToExistingOrdersMap.get(existingOrder.ContractId).add(existingOrder);
        }
        
        // Check for Draft Orders and add error with Order Numbers
        for (Order order : newOrderList) {
            if (order.ContractId == null) {
                System.debug('Skipping Order ' + order.Id + ': ContractId is null.');
                continue;
            }
            List<Order> existingOrdersForContract = contractToExistingOrdersMap.get(order.ContractId);
            if (existingOrdersForContract != null) {
                List<String> draftOrderNumbers = new List<String>();
                for (Order existingOrder : existingOrdersForContract) {
                    if (existingOrder.Sales_Order_Approval__c == 'Draft') {
                        draftOrderNumbers.add(existingOrder.OrderNumber);
                    }
                }
                if (!draftOrderNumbers.isEmpty()) {
                    order.addError('Cannot create new Order while Draft Orders exist for this Contract. Affected Orders: ' + String.join(draftOrderNumbers, ', '));
                    System.debug('Error added to Order ' + order.Id + ': Found Draft Orders: ' + String.join(draftOrderNumbers, ', '));
                }
            }
        }
        
        // Step 2: Query Contracts with Status 'Approved' and matching Opportunity__c
        Map<Id, Contract> contractMap = new Map<Id, Contract>([
            SELECT Id, Opportunity__c, ContractApprovalStatus__c, Purchase_Order_Name__c, Text_Header__c
            FROM Contract
            WHERE Id IN :contractIds
            AND Opportunity__c IN :oppIds
            AND ContractApprovalStatus__c = 'Approved'
        ]);
        
        // Step 3: Query Purchase Orders to get Quote__c
        Set<Id> poIds = new Set<Id>();
        for (Contract contract : contractMap.values()) {
            if (contract.Purchase_Order_Name__c != null) {
                poIds.add(contract.Purchase_Order_Name__c);
            }
        }
        
        Map<Id, Purchase_Order__c> poMap = new Map<Id, Purchase_Order__c>([
            SELECT Id, Quote__c
            FROM Purchase_Order__c
            WHERE Id IN :poIds
        ]);
        
        // Step 4: Query Quotes for Pricebook2Id
        Set<Id> quoteIds = new Set<Id>();
        for (Purchase_Order__c po : poMap.values()) {
            if (po.Quote__c != null) {
                quoteIds.add(po.Quote__c);
            }
        }
        
        Map<Id, Quote> quoteMap = new Map<Id, Quote>([
            SELECT Id, Pricebook2Id
            FROM Quote
            WHERE Id IN :quoteIds
        ]);
        
        // Step 5: Query Sales Contract Line Items for the valid Contracts
        Map<Id, List<Sales_Contract_Line_Item__c>> contractToLinesMap = new Map<Id, List<Sales_Contract_Line_Item__c>>();
        List<Sales_Contract_Line_Item__c> scLis = [
            SELECT Id, Contract__c, Product__c, Quantity__c, Amount__c, List_Price__c, 
            Discount__c, Other_Expenses__c, Freight__c, Packing_and_Forwarding__c, 
            Shipping_and_Handling__c, Product_Number__c, GST_Tax_Percentage__c,Plant__c,Reason_for_Rejection__c,Text_Item__c,Contract_Document_Item_Number__c,Pricing_Conditions__c
            FROM Sales_Contract_Line_Item__c
            WHERE Contract__c IN :contractIds
        ];
        for (Sales_Contract_Line_Item__c scLi : scLis) {
            //  Skip rejected contract lines
            if (String.isNotBlank(scLi.Reason_for_Rejection__c)) {
                continue;
            }
            if (!contractToLinesMap.containsKey(scLi.Contract__c)) {
                contractToLinesMap.put(scLi.Contract__c, new List<Sales_Contract_Line_Item__c>());
            }
            contractToLinesMap.get(scLi.Contract__c).add(scLi);
        }
        
        // Debug: Log Sales Contract Line Items
        for (Id contractId : contractToLinesMap.keySet()) {
            List<Sales_Contract_Line_Item__c> lines = contractToLinesMap.get(contractId);
            System.debug('Contract ' + contractId + ' has ' + lines.size() + ' line items');
            for (Sales_Contract_Line_Item__c scLi : lines) {
                System.debug('Contract line: Product = ' + scLi.Product__c + ', Quantity = ' + scLi.Quantity__c + 
                             ', List_Price = ' + scLi.List_Price__c + ', Amount = ' + scLi.Amount__c + 
                             ', Discount = ' + scLi.Discount__c + ', Freight = ' + scLi.Freight__c + 
                             ', Other Expenses = ' + scLi.Other_Expenses__c + ', Packing = ' + scLi.Packing_and_Forwarding__c + 
                             ', Shipping = ' + scLi.Shipping_and_Handling__c);
            }
        }
        
        // Step 6: Query QuoteLineItems for PricebookEntryId
        Map<String, Id> productToPricebookEntryId = new Map<String, Id>();
        Map<String, Decimal> productToQuoteUnitPrice = new Map<String, Decimal>();
        for (QuoteLineItem qli : [
            SELECT QuoteId, Product2Id, PricebookEntryId, UnitPrice
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
        ]) {
            productToPricebookEntryId.put(qli.QuoteId + '-' + qli.Product2Id, qli.PricebookEntryId);
            productToQuoteUnitPrice.put(qli.QuoteId + '-' + qli.Product2Id, qli.UnitPrice);
        }
        
        /* -------------------------------------------------
* BULK PricebookEntry lookup (ADDED)
* ------------------------------------------------- */
        Set<Id> allProductIds = new Set<Id>();
        Set<Id> allPricebook2Ids = new Set<Id>();
        
        // Collect Product Ids from Sales Contract Lines
        for (List<Sales_Contract_Line_Item__c> scLines : contractToLinesMap.values()) {
            for (Sales_Contract_Line_Item__c scLi : scLines) {
                if (scLi.Product__c != null) {
                    allProductIds.add(scLi.Product__c);
                }
            }
        }
        
        // Collect Pricebook2 Ids from Quotes
        for (Quote q : quoteMap.values()) {
            if (q.Pricebook2Id != null) {
                allPricebook2Ids.add(q.Pricebook2Id);
            }
        }
        
        Map<String, PricebookEntry> pricebookEntryLookup = new Map<String, PricebookEntry>();
        
        if (!allProductIds.isEmpty() && !allPricebook2Ids.isEmpty()) {
            for (PricebookEntry pbe : [
                SELECT Id, Product2Id, Pricebook2Id, UnitPrice
                FROM PricebookEntry
                WHERE Product2Id IN :allProductIds
                AND Pricebook2Id IN :allPricebook2Ids
                AND IsActive = true
            ]) {
                String key = pbe.Pricebook2Id + '-' + pbe.Product2Id;
                pricebookEntryLookup.put(key, pbe);
            }
        }
        
        // Step 7: Query approved OrderItems for the Contracts to compute sums
        List<OrderItem> approvedLines = [
            SELECT Product2Id, Quantity, TotalPrice, Order.ContractId, Product_Code__c
            FROM OrderItem
            WHERE Order.ContractId IN :contractIds
            AND Order.Sales_Order_Approval__c = 'Approved'
        ];
        
        // Debug: Log Approved Lines
        System.debug('Number of approved lines: ' + approvedLines.size());
        for (OrderItem line : approvedLines) {
            System.debug('Approved line: Product = ' + line.Product2Id + ', Quantity = ' + line.Quantity + 
                         ', TotalPrice = ' + line.TotalPrice + ', Order = ' + line.OrderId + 
                         ', Contract = ' + line.Order.ContractId + ', Product_Code = ' + line.Product_Code__c);
        }
        
        // Step 8: Aggregate sums per Contract per Product
        Map<Id, Map<Id, Decimal>> contractToProductToSumQty = new Map<Id, Map<Id, Decimal>>();
        Map<Id, Map<Id, Decimal>> contractToProductToSumTotal = new Map<Id, Map<Id, Decimal>>();
        Map<Id, String> productToProductCode = new Map<Id, String>();
        for (OrderItem line : approvedLines) {
            Id contractId = line.Order.ContractId;
            Id prodId = line.Product2Id;
            if (contractId == null || prodId == null) {
                System.debug('Skipping approved line: Contract or Product is null for Order ' + line.OrderId);
                continue;
            }
            
            productToProductCode.put(prodId, line.Product_Code__c != null ? line.Product_Code__c : 'Unknown');
            
            if (!contractToProductToSumQty.containsKey(contractId)) {
                contractToProductToSumQty.put(contractId, new Map<Id, Decimal>());
                contractToProductToSumTotal.put(contractId, new Map<Id, Decimal>());
            }
            
            Map<Id, Decimal> prodQtyMap = contractToProductToSumQty.get(contractId);
            Map<Id, Decimal> prodTotalMap = contractToProductToSumTotal.get(contractId);
            
            Decimal lineQty = line.Quantity != null ? line.Quantity : 0;
            Decimal lineTotal = line.TotalPrice != null ? line.TotalPrice : 0;
            
            Decimal currentQty = prodQtyMap.get(prodId) != null ? prodQtyMap.get(prodId) : 0;
            Decimal currentTotal = prodTotalMap.get(prodId) != null ? prodTotalMap.get(prodId) : 0;
            
            prodQtyMap.put(prodId, currentQty + lineQty);
            prodTotalMap.put(prodId, currentTotal + lineTotal);
            System.debug('Aggregated for Contract ' + contractId + ', Product ' + prodId + 
                         ': Previous Qty = ' + currentQty + ', Line Qty = ' + lineQty + 
                         ', New Qty Total = ' + (currentQty + lineQty));
        }
        
        // Debug: Log Aggregated Used Quantities
        for (Id contractId : contractToProductToSumQty.keySet()) {
            Map<Id, Decimal> prodMap = contractToProductToSumQty.get(contractId);
            System.debug('Aggregated used quantities for Contract ' + contractId + ':');
            for (Id prodId : prodMap.keySet()) {
                System.debug('  Product ' + prodId + ': used qty = ' + prodMap.get(prodId));
            }
        }
        
        // Step 9: Initialize lists and maps for line items, validation, and PricebookEntry updates
        List<OrderItem> orderItemsToInsert = new List<OrderItem>();
        Map<Id, Integer> orderToLineItemCount = new Map<Id, Integer>();
        Map<Id, List<String>> orderToNoRemainingProducts = new Map<Id, List<String>>();
        List<Order> orderUpdates = new List<Order>(); // For updating Pricebook2Id
        List<PricebookEntry> pricebookEntriesToUpsert = new List<PricebookEntry>();
        
        // Step 10: Process each new Order
        for (Order order : newOrderList) {
            
            // Prevent reprocessing same Order (ADD THIS BLOCK)
            if (processedOrderIds.contains(order.Id)) {
                continue;
            }
            processedOrderIds.add(order.Id);
            
            // Existing validation (KEEP AS IS)
            if (order.hasErrors() || order.ContractId == null || order.OpportunityId == null) {
                System.debug('Skipping Order ' + order.Id + ': Has errors or missing Contract/Opportunity.');
                continue;
            }
            
            Contract c = contractMap.get(order.ContractId);
            if (c == null || c.Opportunity__c != order.OpportunityId) {
                System.debug('Skipping Order ' + order.Id + ': Contract ' + order.ContractId + 
                             ' is not Approved or does not match Opportunity ' + order.OpportunityId);
                continue;
            }
            
            // Set Order.Pricebook2Id via DML update
            Id pricebook2Id;
            Purchase_Order__c po = poMap.get(c.Purchase_Order_Name__c);
            if (po != null && po.Quote__c != null) {
                Quote quote = quoteMap.get(po.Quote__c);
                if (quote != null && quote.Pricebook2Id != null) {
                    pricebook2Id = quote.Pricebook2Id;
                    if (order.Pricebook2Id == null && pricebook2Id != null) {
                        order.Pricebook2Id = pricebook2Id;
                    }
                }
            }
            
            List<Sales_Contract_Line_Item__c> cLines = contractToLinesMap.get(c.Id);
            if (cLines == null || cLines.isEmpty()) {
                System.debug('No Sales Contract Line Items found for Contract: ' + c.Id);
                order.addError('No Sales Contract Line Items found for selected Contract  Or Sales Contract Line Items are blocked' +  
                               ', cannot create Order.');
                System.debug('Error added to Order ' + order.Id + ': No Sales Contract Line Items.');
                continue;
            }
            
            System.debug('Processing Order ' + order.Id + ' with ' + cLines.size() + ' Sales Contract Line Items');
            
            Map<Id, Decimal> productToUsedQty = contractToProductToSumQty.get(order.ContractId);
            if (productToUsedQty == null) {
                productToUsedQty = new Map<Id, Decimal>();
                System.debug('No aggregated used quantities for Contract ' + order.ContractId + ', using empty map');
            } else {
                System.debug('Using aggregated used quantities for Contract ' + order.ContractId + ': ' + productToUsedQty);
            }
            
            Integer createdCount = 0;
            List<String> noRemainingProducts = new List<String>();
            for (Sales_Contract_Line_Item__c cLi : cLines) {
                if (cLi.Product__c == null) {
                    System.debug('Skipping Sales Contract Line Item ' + cLi.Id + ': Product__c is null.');
                    continue;
                }
                
                Decimal origQty = cLi.Quantity__c != null ? cLi.Quantity__c : 0;
                Decimal unitPrice = cLi.List_Price__c != null ? cLi.List_Price__c : 0;
                Id prodId = cLi.Product__c;
                
                if (origQty <= 0) {
                    System.debug('Skipping Sales Contract Line Item ' + cLi.Id + ': Quantity is ' + origQty);
                    continue;
                }
                
                Decimal usedQty = productToUsedQty.get(prodId) != null ? productToUsedQty.get(prodId) : 0;
                System.debug('For Sales Contract Line Item ' + cLi.Id + ', Product ' + prodId + 
                             ': Orig Qty = ' + origQty + ', Used Qty = ' + usedQty);
                
                Decimal remainingQty = origQty - usedQty;
                if (remainingQty <= 0) {
                    String productCode = cLi.Product_Number__c != null ? cLi.Product_Number__c : 'Unknown';
                    System.debug('Skipping Sales Contract Line Item ' + cLi.Id + ' for Product ' + prodId + 
                                 ' (' + productCode + '): Remaining Quantity is ' + remainingQty + 
                                 ' (orig: ' + origQty + ', used: ' + usedQty + ')');
                    noRemainingProducts.add(productCode);
                    continue;
                }
                
                // Calculate per-unit values for Discount, Freight, etc.
                //Decimal perUnitDiscount = (cLi.Discount__c != null && origQty > 0) ? cLi.Discount__c / origQty : 0;
                Decimal perUnitFreight = (cLi.Freight__c != null && origQty > 0) ? cLi.Freight__c / origQty : 0;
                Decimal perUnitOtherExpenses = (cLi.Other_Expenses__c != null && origQty > 0) ? cLi.Other_Expenses__c / origQty : 0;
                Decimal perUnitShipping = (cLi.Shipping_and_Handling__c != null && origQty > 0) ? cLi.Shipping_and_Handling__c / origQty : 0;
                Decimal perUnitPacking = (cLi.Packing_and_Forwarding__c != null && origQty > 0) ? cLi.Packing_and_Forwarding__c / origQty : 0;
                
                // Calculate proportional values for OrderItem
                //Decimal discount = perUnitDiscount * remainingQty;
                Decimal freight = perUnitFreight * remainingQty;
                Decimal otherExpenses = perUnitOtherExpenses * remainingQty;
                Decimal shipping = perUnitShipping * remainingQty;
                Decimal packing = perUnitPacking * remainingQty;
                
                // Get PricebookEntryId
                Id pricebookEntryId;
                if (po != null && po.Quote__c != null) {
                    String key = po.Quote__c + '-' + prodId;
                    pricebookEntryId = productToPricebookEntryId.get(key);
                }
                
                // Create or update PricebookEntry to match List_Price__c
                if (pricebookEntryId == null && pricebook2Id != null) {
                    String pbKey = pricebook2Id + '-' + prodId;
                    PricebookEntry existingEntry = pricebookEntryLookup.get(pbKey);
                    
                    if (existingEntry != null) {
                        pricebookEntryId = existingEntry.Id;
                        
                        if (existingEntry.UnitPrice != unitPrice) {
                            existingEntry.UnitPrice = unitPrice;
                            pricebookEntriesToUpsert.add(existingEntry);
                        }
                    } else if (pricebook2Id != null) {
                        PricebookEntry newEntry = new PricebookEntry(
                            Pricebook2Id = pricebook2Id,
                            Product2Id = prodId,
                            UnitPrice = unitPrice,
                            IsActive = true
                        );
                        pricebookEntriesToUpsert.add(newEntry);
                        pricebookEntryLookup.put(pricebook2Id + '-' + prodId, newEntry);
                    }
                }
                
                if (pricebookEntryId == null && pricebookEntriesToUpsert.isEmpty()) {
                    System.debug('No PricebookEntry found for Product ' + prodId + ' in Order ' + order.Id);
                    continue; // Skip if no PricebookEntry
                }
                system.debug('debug log--');
                
                OrderItem newOrderItem = new OrderItem(
                    OrderId = order.Id,
                    Product2Id = prodId,
                    Quantity = remainingQty,
                    UnitPrice = unitPrice, // From Sales_Contract_Line_Item__c.List_Price__c
                    PricebookEntryId = pricebookEntryId,
                    Discount__c = cLi.Discount__c,
                    Freight__c = freight,
                    Other_Expenses__c = otherExpenses,
                    Shipping_and_Handling__c = shipping,
                    Packing_and_Forwarding__c = packing,
                    GST_Tax_Percentage__c = cLi.GST_Tax_Percentage__c,
                    Plant__c = cLi.Plant__c,
                    Text_Item__c = cLi.Text_Item__c,
                    Pricing_Condition__c = PricingConditionController.filterPricingConditions(cLi.Pricing_Conditions__c),
                    Order_Document_Item_Number__c = cLi.Contract_Document_Item_Number__c
                );
                orderItemsToInsert.add(newOrderItem);
                createdCount++;
                system.debug('debug log--');
                system.debug('newOrderItem' + newOrderItem);
                system.debug('createdCount' + createdCount);
                System.debug('Created Order Item #' + createdCount + ' for Order ' + order.Id + 
                             ', Product ' + prodId + ' (' + cLi.Product_Number__c + '), Qty ' + remainingQty + 
                             ' (orig: ' + origQty + ', used: ' + usedQty + '), UnitPrice = ' + unitPrice + 
                             ', PricebookEntryId = ' + pricebookEntryId);
                System.debug('Freight: ' + freight + 
                             ', Other Expenses: ' + otherExpenses + ', Shipping: ' + shipping + 
                             ', Packing: ' + packing);
            }
            
            orderToLineItemCount.put(order.Id, createdCount);
            if (createdCount == 0) {
                orderToNoRemainingProducts.put(order.Id, noRemainingProducts);
            }
            System.debug('Total Order Items created for Order ' + order.Id + ': ' + createdCount);
        }
        
        // Step 11: Upsert PricebookEntries
        if (!pricebookEntriesToUpsert.isEmpty()) {
            try {
                upsert pricebookEntriesToUpsert;
                System.debug('Upserted ' + pricebookEntriesToUpsert.size() + ' PricebookEntries.');
                // Update PricebookEntryId for new entries
                for (PricebookEntry pbe : pricebookEntriesToUpsert) {
                    for (OrderItem item : orderItemsToInsert) {
                        if (item.Product2Id == pbe.Product2Id && item.PricebookEntryId == null) {
                            item.PricebookEntryId = pbe.Id;
                        }
                    }
                }
            } catch (Exception e) {
                System.debug('Error upserting PricebookEntries: ' + e.getMessage());
                for (Order order : newOrderList) {
                    order.addError('Failed to create/update PricebookEntry: ' + e.getMessage());
                }
            }
        }
        
        /*// Step 12: Update Orders with Pricebook2Id
if (!orderUpdates.isEmpty()) {
try {
update orderUpdates;
System.debug('Updated ' + orderUpdates.size() + ' Orders with Pricebook2Id.');
} catch (Exception e) {
System.debug('Error updating Orders with Pricebook2Id: ' + e.getMessage());
for (Order order : newOrderList) {
order.addError('Failed to set Pricebook2Id: ' + e.getMessage());
}
}
}*/
        
        // Step 13: Validate that at least one line item exists for each Order
        for (Order order : newOrderList) {
            if (order.hasErrors()) {
                continue; // Skip if already has errors
            }
            system.debug('order.Id' + order.Id);
            system.debug('orderToLineItemCount' + orderToLineItemCount);
            Integer lineItemCount = orderToLineItemCount.get(order.Id);
            system.debug('lineItemCount' + lineItemCount);
            if (lineItemCount == null || lineItemCount == 0) {
                List<String> noRemainingProducts = orderToNoRemainingProducts.get(order.Id);
                String errorMsg = 'No remaining products to be added, cannot create Order.';
                if (noRemainingProducts != null && !noRemainingProducts.isEmpty()) {
                    errorMsg += ' Products with no remaining quantities: ' + String.join(noRemainingProducts, ', ');
                }
                order.addError(errorMsg);
                System.debug('Error added to Order ' + order.Id + ': ' + errorMsg);
            }
        }
        
        // Step 14: Insert Order Items
        if (!orderItemsToInsert.isEmpty()) {
            try {
                insert orderItemsToInsert;
                System.debug('Inserted ' + orderItemsToInsert.size() + ' Order Items.');
            } catch (Exception e) {
                System.debug('Error inserting Order Items: ' + e.getMessage());
                for (OrderItem line : orderItemsToInsert) {
                    Order order = new Order(Id = line.OrderId);
                    order.addError('Failed to create Order Item for Product ' + line.Product_Code__c + ': ' + e.getMessage());
                }
            }
        } else {
            System.debug('No Order Items to insert.');
        }
        
        //isRunning = false; // Reset recursion guard
    }
    
    /**
* @description Validates Order quantities when status changes to 'Approved'.
* Ensures the sum of OrderItem quantities per product does not exceed the Sales Contract quantities.
* Adds error if any product exceeds, listing affected products by Product_Code__c.
* @param newOrders List of updated Order records
* @param oldMap Map of old Order records for comparison
*/
    public static void validateApprovalQuantities(List<Order> newOrders, Map<Id, Order> oldMap) {
        if (!Trigger.isUpdate) {
            return;
        }
        
        
        // Collect Orders being approved
        Set<Id> approvingOrderIds = new Set<Id>();
        Set<Id> contractIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        for (Order newOrder : newOrders) {
            Order oldOrder = oldMap.get(newOrder.Id);
            if (newOrder.Status == 'Approved' && oldOrder.Status != 'Approved') {
                approvingOrderIds.add(newOrder.Id);
                if (newOrder.ContractId != null) {
                    contractIds.add(newOrder.ContractId);
                }
            }
        }
        
        if (approvingOrderIds.isEmpty()) {
            return; // No Orders being approved
        }
        
        // Query Sales Contract Line Items for original quantities
        Map<String, Decimal> contractProductToQty = new Map<String, Decimal>();
        for (Sales_Contract_Line_Item__c scLi : [
            SELECT Contract__c, Product__c, Quantity__c
            FROM Sales_Contract_Line_Item__c
            WHERE Contract__c IN :contractIds
        ]) {
            contractProductToQty.put(scLi.Contract__c + '-' + scLi.Product__c, scLi.Quantity__c);
            productIds.add(scLi.Product__c);
        }
        
        // Query all OrderItems to sum quantities and collect Product_Code__c
        Map<String, Decimal> contractProductToApprovedQty = new Map<String, Decimal>();
        Map<Id, Map<Id, Decimal>> orderToProductSum = new Map<Id, Map<Id, Decimal>>();
        Map<Id, String> productToProductCode = new Map<Id, String>();
        for (OrderItem line : [
            SELECT Product2Id, Quantity, OrderId, Order.ContractId, Order.Status, Product_Code__c
            FROM OrderItem
            WHERE Order.ContractId IN :contractIds
            AND Product2Id != null
        ]) {
            Id contractId = line.Order.ContractId;
            Id prodId = line.Product2Id;
            Decimal qty = line.Quantity != null ? line.Quantity : 0;
            String productCode = line.Product_Code__c != null ? line.Product_Code__c : 'Unknown';
            productToProductCode.put(prodId, productCode);
            
            // Aggregate approved sums (excluding approving Orders' lines)
            if (line.Order.Status == 'Approved' && !approvingOrderIds.contains(line.OrderId)) {
                String key = contractId + '-' + prodId;
                Decimal currentSum = contractProductToApprovedQty.get(key) != null ? contractProductToApprovedQty.get(key) : 0;
                contractProductToApprovedQty.put(key, currentSum + qty);
            }
            
            // Sum for approving Orders' own line items
            if (approvingOrderIds.contains(line.OrderId)) {
                if (!orderToProductSum.containsKey(line.OrderId)) {
                    orderToProductSum.put(line.OrderId, new Map<Id, Decimal>());
                }
                Map<Id, Decimal> prodSum = orderToProductSum.get(line.OrderId);
                Decimal currentProdSum = prodSum.get(prodId) != null ? prodSum.get(prodId) : 0;
                prodSum.put(prodId, currentProdSum + qty);
            }
        }
        
        // Validate each approving Order's line item sums
        for (Order newOrder : newOrders) {
            if (approvingOrderIds.contains(newOrder.Id)) {
                Map<Id, Decimal> orderProductSums = orderToProductSum.get(newOrder.Id);
                if (orderProductSums == null) {
                    continue; // No line items
                }
                
                List<String> exceedingProducts = new List<String>();
                for (Id prodId : orderProductSums.keySet()) {
                    Decimal orderSum = orderProductSums.get(prodId);
                    
                    // Get Contract quantity
                    String contractKey = newOrder.ContractId + '-' + prodId;
                    Decimal contractQty = contractProductToQty.get(contractKey) != null ? contractProductToQty.get(contractKey) : 0;
                    
                    // Get other approved sum
                    String approvedKey = newOrder.ContractId + '-' + prodId;
                    Decimal otherApprovedSum = contractProductToApprovedQty.get(approvedKey) != null ? 
                        contractProductToApprovedQty.get(approvedKey) : 0;
                    
                    Decimal remainingLimit = contractQty - otherApprovedSum;
                    if (orderSum > remainingLimit) {
                        String productCode = productToProductCode.get(prodId);
                        exceedingProducts.add(productCode + ' (Order sum: ' + orderSum + ', Remaining: ' + remainingLimit + ')');
                    }
                }
                
                if (!exceedingProducts.isEmpty()) {
                    newOrder.addError('Order quantities exceed remaining Sales Contract quantities for the following products: ' + 
                                      String.join(exceedingProducts, '; '));
                }
            }
        }
    }
    
    
    /**
* Once Order is Approved → Freeze it completely
* Allow editing only: Trigger_SAP_Insert__c & SAP_Sales_Order_Number__c
*/
    public static void freezeApprovedOrder(List<Order> newOrders,Map<Id, Order> oldMap){        
        // Fields allowed even after approval
        Set<String> allowedFields = new Set<String>{'Trigger_SAP_Insert__c','SAP_Sales_Order_Number__c'};
            
            for(Order newOrd : newOrders){
                
                Order oldOrd = oldMap.get(newOrd.Id);
                
                // Apply only when Order is Approved
                if(newOrd.Sales_Order_Approval__c == 'Approved'){
                    
                    Boolean onlyAllowedChange = true;
                    
                    for(String field : newOrd.getPopulatedFieldsAsMap().keySet()){
                        
                        // Skip system + approval + allowed fields
                        if(field == 'Id'
                           || field == 'Sales_Order_Approval__c'
                           || allowedFields.contains(field)){
                               continue;
                           }
                        
                        if(newOrd.get(field) != oldOrd.get(field)){
                            onlyAllowedChange = false;
                            break;
                        }
                    }
                    
                    if(!onlyAllowedChange){
                        newOrd.addError(
                            'This Order is APPROVED and FROZEN.\n' +
                            'You cannot modify any fields. Order Number: ' + newOrd.OrderNumber
                        );
                    }
                }
            }
    }
    
    
}