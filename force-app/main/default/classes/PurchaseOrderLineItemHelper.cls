Public with sharing class PurchaseOrderLineItemHelper {

    /**
     * Populate Sales Price from QuoteLineItem if missing
     */
    public static void populateSalesPrice(List<Purchase_Order_Line_Item__c> newLines) {
        Set<Id> poIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        for (Purchase_Order_Line_Item__c line : newLines) {
            if (line.Purchase_Order__c != null) poIds.add(line.Purchase_Order__c);
            if (line.Product__c != null) productIds.add(line.Product__c);
        }

        if (poIds.isEmpty() || productIds.isEmpty()) return;

        Map<Id, Purchase_Order__c> poMap = new Map<Id, Purchase_Order__c>([
            SELECT Id, Quote__c 
            FROM Purchase_Order__c 
            WHERE Id IN :poIds
        ]);

        Set<Id> quoteIds = new Set<Id>();
        for (Purchase_Order__c po : poMap.values()) {
            if (po.Quote__c != null) quoteIds.add(po.Quote__c);
        }

        Map<String, Decimal> quoteProductToPrice = new Map<String, Decimal>();
        for (QuoteLineItem qli : [
            SELECT QuoteId, Product2Id, UnitPrice 
            FROM QuoteLineItem 
            WHERE QuoteId IN :quoteIds AND Product2Id IN :productIds
        ]) {
            quoteProductToPrice.put(qli.QuoteId + '-' + qli.Product2Id, qli.UnitPrice);
        }

        for (Purchase_Order_Line_Item__c line : newLines) {
            if (line.Sales_Price__c == null && line.Product__c != null && line.Purchase_Order__c != null) {
                Purchase_Order__c po = poMap.get(line.Purchase_Order__c);
                if (po != null && po.Quote__c != null) {
                    String key = po.Quote__c + '-' + line.Product__c;
                    Decimal unitPrice = quoteProductToPrice.get(key);
                    if (unitPrice != null) {
                        line.Sales_Price__c = unitPrice;
                    } else {
                        line.addError('Cannot populate Sales Price: No matching Quote Line Item for Product ' + line.Product__c);
                    }
                }
            }
        }
    }

    /**
     * Recalculate totals and validate against Quote limits
     */
   public static void recalculateTotalAndValidateLimit(List<Purchase_Order_Line_Item__c> newLines, Map<Id, Purchase_Order_Line_Item__c> oldMap) {
    // collect PO and Product ids for queries & early exit
    Set<Id> poIds = new Set<Id>();
    Set<Id> productIds = new Set<Id>();
    for (Purchase_Order_Line_Item__c line : newLines) {
        Purchase_Order_Line_Item__c oldLine = oldMap.get(line.Id);
        if (oldLine == null) continue;
        if (line.Quantity__c != oldLine.Quantity__c) {
            if (line.Purchase_Order__c != null) poIds.add(line.Purchase_Order__c);
            if (line.Product__c != null) productIds.add(line.Product__c);
        }
    }
    if (poIds.isEmpty() || productIds.isEmpty()) return;

    // fetch parent POs
    Map<Id, Purchase_Order__c> poMap = new Map<Id, Purchase_Order__c>([
        SELECT Id, Quote__c, Opportunity__c, PO_Approval_Status__c
        FROM Purchase_Order__c
        WHERE Id IN :poIds
    ]);

    // collect quoteIds and oppIds
    Set<Id> quoteIds = new Set<Id>();
    Set<Id> oppIds = new Set<Id>();
    for (Purchase_Order__c p : poMap.values()) {
        if (p.Quote__c != null) quoteIds.add(p.Quote__c);
        if (p.Opportunity__c != null) oppIds.add(p.Opportunity__c);
    }

    // quote -> product original quantities
    Map<String, Decimal> quoteProductToQty = new Map<String, Decimal>();
    if (!quoteIds.isEmpty()) {
        for (QuoteLineItem qli : [
            SELECT QuoteId, Product2Id, Quantity
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds AND Product2Id IN :productIds
        ]) {
            quoteProductToQty.put(qli.QuoteId + '-' + qli.Product2Id, qli.Quantity);
        }
    }

    // approved totals per Opportunity+Product (used to compute remaining limit)
    Map<String, Decimal> oppProductToApprovedQty = new Map<String, Decimal>();
    if (!oppIds.isEmpty()) {
        for (Purchase_Order_Line_Item__c approvedLine : [
            SELECT Product__c, Quantity__c, Purchase_Order__r.Opportunity__c
            FROM Purchase_Order_Line_Item__c
            WHERE Purchase_Order__r.Opportunity__c IN :oppIds
              AND Purchase_Order__r.PO_Approval_Status__c = 'Approved'
              AND Product__c IN :productIds
        ]) {
            String key = approvedLine.Purchase_Order__r.Opportunity__c + '-' + approvedLine.Product__c;
            Decimal curr = oppProductToApprovedQty.containsKey(key) ? oppProductToApprovedQty.get(key) : 0;
            curr += (approvedLine.Quantity__c != null ? approvedLine.Quantity__c : 0);
            oppProductToApprovedQty.put(key, curr);
        }
    }

    // Now iterate lines and compute per-unit from oldLine (previous state), apply to new quantity
    for (Purchase_Order_Line_Item__c line : newLines) {
        Purchase_Order_Line_Item__c oldLine = oldMap.get(line.Id);
        if (oldLine == null) continue;
        if (line.Quantity__c == oldLine.Quantity__c) continue;

        Decimal newQty = (line.Quantity__c != null ? line.Quantity__c : 0);
        Decimal oldQty = (oldLine.Quantity__c != null ? oldLine.Quantity__c : 0);

        // If oldQty > 0, compute per-unit from old values; else per-unit = 0 (guard against divide-by-zero)
        Decimal perUnitDiscount = 0;
        Decimal perUnitFreight = 0;
        Decimal perUnitOtherExpenses = 0;
        Decimal perUnitShipping = 0;
        Decimal perUnitPacking = 0;

        if (oldQty > 0) {
            //perUnitDiscount = (oldLine.Discount__c != null ? oldLine.Discount__c : 0) / oldQty;
            perUnitFreight = (oldLine.Freight__c != null ? oldLine.Freight__c : 0) / oldQty;
            perUnitOtherExpenses = (oldLine.Other_expenses__c != null ? oldLine.Other_expenses__c : 0) / oldQty;
            perUnitShipping = (oldLine.Shipping_and_Handling__c != null ? oldLine.Shipping_and_Handling__c : 0) / oldQty;
            perUnitPacking = (oldLine.Packing_and_Forwarding__c != null ? oldLine.Packing_and_Forwarding__c : 0) / oldQty;
        }

        // Apply proportional values to new quantity
        //line.Discount__c = perUnitDiscount * newQty;
        line.Freight__c = perUnitFreight * newQty;
        line.Other_expenses__c = perUnitOtherExpenses * newQty;
        line.Shipping_and_Handling__c = perUnitShipping * newQty;
        line.Packing_and_Forwarding__c = perUnitPacking * newQty;

        // ---- keep your remaining-quote validation ----
        Purchase_Order__c po = poMap.get(line.Purchase_Order__c);
        if (po == null || po.Quote__c == null || line.Product__c == null) continue;

        String quoteKey = po.Quote__c + '-' + line.Product__c;
        Decimal quoteQty = quoteProductToQty.containsKey(quoteKey) ? quoteProductToQty.get(quoteKey) : 0;

        String approvedKey = po.Opportunity__c + '-' + line.Product__c;
        Decimal totalApproved = oppProductToApprovedQty.containsKey(approvedKey) ? oppProductToApprovedQty.get(approvedKey) : 0;

        // if current PO is already Approved, subtract oldLine qty (we're editing an Approved PO line)
        if (po.PO_Approval_Status__c == 'Approved') {
            totalApproved -= (oldLine.Quantity__c != null ? oldLine.Quantity__c : 0);
        }

        Decimal remainingLimit = quoteQty - totalApproved;

        if (newQty > remainingLimit) {
            line.addError('Quantity exceeds remaining Quote quantity for Product ' + String.valueOf(line.Product__c) + '. Remaining limit: ' + remainingLimit);
        }
    }
}


    /**
     * Collect parent PO Ids
     */
    public static Set<Id> collectPoIds(List<Purchase_Order_Line_Item__c> lineItems) {
        Set<Id> poIds = new Set<Id>();
        for (Purchase_Order_Line_Item__c li : lineItems) {
            if (li.Purchase_Order__c != null) {
                poIds.add(li.Purchase_Order__c);
            }
        }
        return poIds;
    }

    /**
     * Rollup totals to Purchase Order
     */
    public static void updatePurchaseOrderTotals(Set<Id> poIds) {
        if (poIds.isEmpty()) return;

        List<Purchase_Order_Line_Item__c> lineItems = [
            SELECT Purchase_Order__c, CGST__c, SGST__c, IGST__c,Total_Amount_New__c
            FROM Purchase_Order_Line_Item__c
            WHERE Purchase_Order__c IN :poIds
        ];

        Map<Id, Decimal> cgstSums = new Map<Id, Decimal>();
        Map<Id, Decimal> sgstSums = new Map<Id, Decimal>();
        Map<Id, Decimal> igstSums = new Map<Id, Decimal>();
        Map<Id, Decimal> totalSums = new Map<Id, Decimal>();

        for (Purchase_Order_Line_Item__c li : lineItems) {
            Id poId = li.Purchase_Order__c;
            cgstSums.put(poId, (cgstSums.get(poId) == null ? 0 : cgstSums.get(poId)) + (li.CGST__c == null ? 0 : li.CGST__c));
            sgstSums.put(poId, (sgstSums.get(poId) == null ? 0 : sgstSums.get(poId)) + (li.SGST__c == null ? 0 : li.SGST__c));
            igstSums.put(poId, (igstSums.get(poId) == null ? 0 : igstSums.get(poId)) + (li.IGST__c == null ? 0 : li.IGST__c));
            totalSums.put(poId, (totalSums.get(poId) == null ? 0 : totalSums.get(poId)) + (li.Total_Amount_New__c == null ? 0 : li.Total_Amount_New__c));
        }

        List<Purchase_Order__c> posToUpdate = new List<Purchase_Order__c>();
        for (Id poId : poIds) {
            posToUpdate.add(new Purchase_Order__c(
                Id = poId,
                CGST__c = cgstSums.get(poId) == null ? 0 : cgstSums.get(poId),
                SGST__c = sgstSums.get(poId) == null ? 0 : sgstSums.get(poId),
                IGST__c = igstSums.get(poId) == null ? 0 : igstSums.get(poId),
                Total_Amount__c = totalSums.get(poId) == null ? 0 : totalSums.get(poId)
            ));
        }

        if (!posToUpdate.isEmpty()) {
            update posToUpdate;
        }
    }
    
   
 
}