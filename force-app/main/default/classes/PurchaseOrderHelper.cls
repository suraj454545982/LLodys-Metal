Public with sharing class PurchaseOrderHelper {

    public static void mapQuoteToPO(List<Purchase_Order__c> newPoList) {
        Set<Id> quoteIds = new Set<Id>();
        Set<Id> oppIds = new Set<Id>();
        Set<Id> newPoIds = new Set<Id>();
        for (Purchase_Order__c po : newPoList) {
            if (po.Quote__c != null) quoteIds.add(po.Quote__c);
            if (po.Opportunity__c != null) oppIds.add(po.Opportunity__c);
            if (po.Id != null) newPoIds.add(po.Id);
        }

        if (quoteIds.isEmpty() || oppIds.isEmpty()) return;

        // Step 1: Validate Draft POs
        Map<Id, List<Purchase_Order__c>> oppToExistingPOsMap = new Map<Id, List<Purchase_Order__c>>();
        for (Purchase_Order__c existingPO : [
            SELECT Id, Opportunity__c, PO_Approval_Status__c, Name
            FROM Purchase_Order__c
            WHERE Opportunity__c IN :oppIds
            AND Id NOT IN :newPoIds
        ]) {
            if (!oppToExistingPOsMap.containsKey(existingPO.Opportunity__c)) {
                oppToExistingPOsMap.put(existingPO.Opportunity__c, new List<Purchase_Order__c>());
            }
            oppToExistingPOsMap.get(existingPO.Opportunity__c).add(existingPO);
        }

        for (Purchase_Order__c po : newPoList) {
            if (po.Opportunity__c == null) continue;
            List<Purchase_Order__c> existingPOsForOpp = oppToExistingPOsMap.get(po.Opportunity__c);
            if (existingPOsForOpp != null) {
                List<String> draftPOIds = new List<String>();
                for (Purchase_Order__c existingPO : existingPOsForOpp) {
                    if (existingPO.PO_Approval_Status__c == 'Draft') draftPOIds.add(existingPO.Name);
                }
                if (!draftPOIds.isEmpty()) po.addError(
                    'Cannot create new Purchase Order while Draft Purchase Orders exist for this Opportunity. Draft PO : ' + 
                    String.join(draftPOIds, ', ')
                );
            }
        }

        // Step 2: Query accepted Quotes
        Map<Id, Quote> quoteMap = new Map<Id, Quote>([
            SELECT Id, OpportunityId 
            FROM Quote 
            WHERE Id IN :quoteIds 
            AND OpportunityId IN :oppIds 
            AND Status = 'Accepted'
        ]);

        // Step 3: Query Quote Line Items
        Map<Id, List<QuoteLineItem>> quoteToLinesMap = new Map<Id, List<QuoteLineItem>>();
        for (QuoteLineItem qli : [
            SELECT Id, QuoteId, Product2Id, Quantity, TotalPrice, UnitPrice,
                   Product2.GST_Percentage__c, Discount__c, Freight__c,
                   Shipping_and_Handling__c, Packing_and_Forwarding__c, Other_expenses__c, GST_Tax_Percentage__c
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
        ]) {
            if (!quoteToLinesMap.containsKey(qli.QuoteId)) quoteToLinesMap.put(qli.QuoteId, new List<QuoteLineItem>());
            quoteToLinesMap.get(qli.QuoteId).add(qli);
        }

        // Step 4: Query approved PO Line Items
        List<Purchase_Order_Line_Item__c> approvedLines = [
            SELECT Product__c, Quantity__c, Purchase_Order__r.Opportunity__c
            FROM Purchase_Order_Line_Item__c
            WHERE Purchase_Order__r.Opportunity__c IN :oppIds
            AND Purchase_Order__r.PO_Approval_Status__c = 'Approved'
        ];
        
        if(approvedLines.isEmpty()){
            System.debug('list is empty');
        }

        Map<Id, Map<Id, Decimal>> oppToProductToSumQty = new Map<Id, Map<Id, Decimal>>();
        Map<Id, Map<Id, Decimal>> oppToProductToSumTotal = new Map<Id, Map<Id, Decimal>>();

        for (Purchase_Order_Line_Item__c line : approvedLines) {
            Id oppId = line.Purchase_Order__r.Opportunity__c;
            Id prodId = line.Product__c;
            if (oppId == null || prodId == null) continue;

            if (!oppToProductToSumQty.containsKey(oppId)) {
                oppToProductToSumQty.put(oppId, new Map<Id, Decimal>());
                oppToProductToSumTotal.put(oppId, new Map<Id, Decimal>());
            }

            Map<Id, Decimal> prodQtyMap = oppToProductToSumQty.get(oppId);
          //  Map<Id, Decimal> prodTotalMap = oppToProductToSumTotal.get(oppId);

            Decimal lineQty = line.Quantity__c != null ? line.Quantity__c : 0;
          //  Decimal lineTotal = line.Total_Amount__c != null ? line.Total_Amount__c : 0;

            prodQtyMap.put(prodId, (prodQtyMap.get(prodId) != null ? prodQtyMap.get(prodId) : 0) + lineQty);
          //  prodTotalMap.put(prodId, (prodTotalMap.get(prodId) != null ? prodTotalMap.get(prodId) : 0) + lineTotal);
        }

        // Step 5: Create new PO Line Items
        List<Purchase_Order_Line_Item__c> poLinesToInsert = new List<Purchase_Order_Line_Item__c>();
        Map<Id, Integer> poToLineItemCount = new Map<Id, Integer>();
        Map<Id, List<String>> poToNoRemainingProducts = new Map<Id, List<String>>();

        for (Purchase_Order__c po : newPoList) {
            if (po.hasErrors() || po.Quote__c == null || po.Opportunity__c == null) continue;

            Quote q = quoteMap.get(po.Quote__c);
            if (q == null || q.OpportunityId != po.Opportunity__c) continue;

            List<QuoteLineItem> qLines = quoteToLinesMap.get(q.Id);
            if (qLines == null || qLines.isEmpty()) {
                po.addError('Quote which you have selected dont have Quote Lines.');
                continue;
            }

            Map<Id, Decimal> productToUsedQty = oppToProductToSumQty.get(po.Opportunity__c);
            if (productToUsedQty == null) productToUsedQty = new Map<Id, Decimal>();

            Integer createdCount = 0;
            List<String> noRemainingProducts = new List<String>();

            for (QuoteLineItem qli : qLines) {
                if (qli.Product2Id == null) continue;

                Decimal origQty = qli.Quantity != null ? qli.Quantity : 0;
                if (origQty <= 0) continue;

                Decimal usedQty = productToUsedQty.get(qli.Product2Id) != null ? productToUsedQty.get(qli.Product2Id) : 0;
                Decimal remainingQty = origQty - usedQty;
                if (remainingQty <= 0) {
                    noRemainingProducts.add(String.valueOf(qli.Product2Id));
                    continue;
                }
                
                 // Calculate per-unit values for Discount, Freight, etc.
                //Decimal perUnitDiscount = (qli.Discount__c != null && origQty > 0) ? qli.Discount__c / origQty : 0;
                Decimal perUnitFreight = (qli.Freight__c != null && origQty > 0) ? qli.Freight__c / origQty : 0;
                Decimal perUnitOtherExpenses = (qli.Other_Expenses__c != null && origQty > 0) ? qli.Other_Expenses__c / origQty : 0;
                Decimal perUnitShipping = (qli.Shipping_and_Handling__c != null && origQty > 0) ? qli.Shipping_and_Handling__c / origQty : 0;
                Decimal perUnitPacking = (qli.Packing_and_Forwarding__c != null && origQty > 0) ? qli.Packing_and_Forwarding__c / origQty : 0;
                
                  // Calculate proportional values for Sales Contract Line Item
                //Decimal discount = perUnitDiscount * remainingQty;
                Decimal freight = perUnitFreight * remainingQty;
                Decimal otherExpenses = perUnitOtherExpenses * remainingQty;
                Decimal shipping = perUnitShipping * remainingQty;
                Decimal packing = perUnitPacking * remainingQty;
                

                Purchase_Order_Line_Item__c newPoLine = new Purchase_Order_Line_Item__c(
                    Purchase_Order__c = po.Id,
                    Product__c = qli.Product2Id,
                    Quantity__c = remainingQty,
                    Sales_Price__c = qli.UnitPrice != null ? qli.UnitPrice : 0,
                    Freight__c =freight,
                    Other_expenses__c = otherExpenses,
                    Packing_and_Forwarding__c =packing,
                    Shipping_and_Handling__c = shipping,
                    //Discount__c = discount,
                    Discount__c = qli.Discount__c,//Changes done for Discount Issue
                    GST_Tax_Percentage__c = qli.GST_Tax_Percentage__c
                );

                poLinesToInsert.add(newPoLine);
                createdCount++;
            }

            poToLineItemCount.put(po.Id, createdCount);
            if (createdCount == 0) poToNoRemainingProducts.put(po.Id, noRemainingProducts);
        }

        // Step 6: Validate at least one line item per PO
        for (Purchase_Order__c po : newPoList) {
            if (po.hasErrors()) continue;

            Integer lineItemCount = poToLineItemCount.get(po.Id);
            if (lineItemCount == null || lineItemCount == 0) {
                po.addError('No remaining products to be added, cannot create Purchase Order.');
            }
        }

        // Step 7: Insert PO Line Items
        if (!poLinesToInsert.isEmpty()) {
            try {
                insert poLinesToInsert;
                
            } catch (Exception e) {
                for (Purchase_Order_Line_Item__c line : poLinesToInsert) {
                    Purchase_Order__c po = new Purchase_Order__c(Id = line.Purchase_Order__c);
                    po.addError('Failed to create PO Line Item for Product ' + line.Product__c + ': ' + e.getMessage());
                }
            }
        }
    }

    public static void fileValidation(List<Purchase_Order__c> newList,Map<Id, Purchase_Order__c> oldMap) {
        // Collect PO ids where status is being set to Approved
        Set<Id> poIdsToCheck = new Set<Id>();
        for (Purchase_Order__c po : newList) {
            if (po.PO_Approval_Status__c == 'Approved' && oldMap.get(po.Id).PO_Approval_Status__c !='Approved' ) {
                poIdsToCheck.add(po.Id);
            }
        }

        if (poIdsToCheck.isEmpty()) return;

        // Check related ContentDocumentLinks (files)
        Map<Id, Integer> poToFileCount = new Map<Id, Integer>();
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :poIdsToCheck
        ]) {
            poToFileCount.put(cdl.LinkedEntityId, 1);
        }

        // Throw error if no file exists for that PO
        for (Purchase_Order__c po : newList) {
            if (poIdsToCheck.contains(po.Id) && !poToFileCount.containsKey(po.Id)) {
                po.addError('You must upload at least one file before approving this Purchase Order.');
            }
        }
    }
}