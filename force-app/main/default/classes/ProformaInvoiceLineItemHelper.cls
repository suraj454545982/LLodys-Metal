public with sharing class ProformaInvoiceLineItemHelper {

    // Populate Sales Price from linked PO Lines
    public static void populateSalesPrice(List<Proforma_Invoice_Line_Item__c> newLines) {
        Set<Id> piIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();

        for (Proforma_Invoice_Line_Item__c line : newLines) {
            if (line.Proforma_Invoice__c != null) piIds.add(line.Proforma_Invoice__c);
            if (line.Product__c != null) productIds.add(line.Product__c);
        }
        if (piIds.isEmpty() || productIds.isEmpty()) return;

        Map<Id, Proforma_Invoice__c> piMap = new Map<Id, Proforma_Invoice__c>(
            [SELECT Id, Purchase_Order__c FROM Proforma_Invoice__c WHERE Id IN :piIds]
        );

        Set<Id> poIds = new Set<Id>();
        for (Proforma_Invoice__c pi : piMap.values()) if (pi.Purchase_Order__c != null) poIds.add(pi.Purchase_Order__c);

        Map<String, Decimal> poProductToPrice = new Map<String, Decimal>();
        for (Purchase_Order_Line_Item__c poli : [
            SELECT Purchase_Order__c, Product__c, Sales_Price__c
            FROM Purchase_Order_Line_Item__c
            WHERE Purchase_Order__c IN :poIds AND Product__c IN :productIds
        ]) {
            poProductToPrice.put(poli.Purchase_Order__c + '-' + poli.Product__c, poli.Sales_Price__c);
        }

        for (Proforma_Invoice_Line_Item__c line : newLines) {
            if (line.Sales_Price__c == null && line.Product__c != null && line.Proforma_Invoice__c != null) {
                Proforma_Invoice__c pi = piMap.get(line.Proforma_Invoice__c);
                if (pi != null && pi.Purchase_Order__c != null) {
                    String key = pi.Purchase_Order__c + '-' + line.Product__c;
                    Decimal price = poProductToPrice.get(key);
                    if (price != null) line.Sales_Price__c = price;
                    else line.addError('No matching PO Line Item for Product ' + line.Product__c);
                }
            }
        }
    }
public static void validateRemainingQuantity(List<Proforma_Invoice_Line_Item__c> newLines, Map<Id, Proforma_Invoice_Line_Item__c> oldMap) {
    if (newLines.isEmpty()) return;

    // Step 1: Collect PI and Product IDs
    Set<Id> piIds = new Set<Id>();
    Set<Id> productIds = new Set<Id>();
    for (Proforma_Invoice_Line_Item__c line : newLines) {
        if (line.Proforma_Invoice__c != null) piIds.add(line.Proforma_Invoice__c);
        if (line.Product__c != null) productIds.add(line.Product__c);
    }
    if (piIds.isEmpty() || productIds.isEmpty()) return;

    // Step 2: Map PI -> PO
    Map<Id, Proforma_Invoice__c> piMap = new Map<Id, Proforma_Invoice__c>(
        [SELECT Id, Purchase_Order__c FROM Proforma_Invoice__c WHERE Id IN :piIds]
    );
    Set<Id> poIds = new Set<Id>();
    for (Proforma_Invoice__c pi : piMap.values()) {
        if (pi.Purchase_Order__c != null) poIds.add(pi.Purchase_Order__c);
    }

    // Step 3: Get PO Line quantities
    Map<String, Decimal> poProductToQty = new Map<String, Decimal>();
    for (Purchase_Order_Line_Item__c poli : [
        SELECT Purchase_Order__c, Product__c, Quantity__c 
        FROM Purchase_Order_Line_Item__c
        WHERE Purchase_Order__c IN :poIds AND Product__c IN :productIds
    ]) {
        poProductToQty.put(
            poli.Purchase_Order__c + '-' + poli.Product__c, 
            poli.Quantity__c != null ? poli.Quantity__c : 0
        );
    }

    // Step 4: Get already used PI Line totals (Approved only)
    Map<String, Decimal> poProductToUsedQty = new Map<String, Decimal>();
    for (Proforma_Invoice_Line_Item__c line : [
        SELECT Id, Proforma_Invoice__c, Product__c, Quantity__c
        FROM Proforma_Invoice_Line_Item__c
        WHERE Proforma_Invoice__c IN :piIds
          AND Proforma_Invoice__r.Status__c = 'Approved'
    ]) {
        Proforma_Invoice__c pi = piMap.get(line.Proforma_Invoice__c);
        if (pi != null && pi.Purchase_Order__c != null) {
            String key = pi.Purchase_Order__c + '-' + line.Product__c;
            Decimal usedQty = poProductToUsedQty.containsKey(key) ? poProductToUsedQty.get(key) : 0;
            poProductToUsedQty.put(key, usedQty + (line.Quantity__c != null ? line.Quantity__c : 0));
        }
    }

    // Step 5: Validate & Recalculate
    for (Proforma_Invoice_Line_Item__c line : newLines) {
        if (line.Product__c == null || line.Proforma_Invoice__c == null) continue;

        Proforma_Invoice__c pi = piMap.get(line.Proforma_Invoice__c);
        if (pi == null || pi.Purchase_Order__c == null) continue;

        String key = pi.Purchase_Order__c + '-' + line.Product__c;
        Decimal poQty   = poProductToQty.containsKey(key) ? poProductToQty.get(key) : 0;
        Decimal usedQty = poProductToUsedQty.containsKey(key) ? poProductToUsedQty.get(key) : 0;
        Decimal newQty  = line.Quantity__c != null ? line.Quantity__c : 0;

        Decimal remainingQty = poQty - usedQty;
        if (newQty > remainingQty) {
            line.addError(
                'Quantity exceeds remaining PO quantity for this product. '
                + 'PO Qty: ' + poQty 
                + ', Already Used: ' + usedQty
                + ', Remaining: ' + remainingQty
                + ', Attempted: ' + newQty
            );
        }

        // --- Recalculate proportional expenses ---
        if (oldMap != null && oldMap.containsKey(line.Id)) {
            Proforma_Invoice_Line_Item__c oldLine = oldMap.get(line.Id);
            Decimal oldQty = oldLine.Quantity__c != null ? oldLine.Quantity__c : 0;

            if (oldQty > 0 && newQty > 0) {
                //Decimal perUnitDiscount       = oldLine.Discount__c != null ? (oldLine.Discount__c / oldQty) : 0;
                Decimal perUnitFreight        = oldLine.Freight__c != null ? (oldLine.Freight__c / oldQty) : 0;
                Decimal perUnitOtherExpenses  = oldLine.Other_expenses__c != null ? (oldLine.Other_expenses__c / oldQty) : 0;
                Decimal perUnitShipping       = oldLine.Shipping_and_Handling__c != null ? (oldLine.Shipping_and_Handling__c / oldQty) : 0;
                Decimal perUnitPacking        = oldLine.Packing_and_Forwarding__c != null ? (oldLine.Packing_and_Forwarding__c / oldQty) : 0;

               // line.Discount__c              = perUnitDiscount * newQty;
                line.Freight__c               = perUnitFreight * newQty;
                line.Other_expenses__c        = perUnitOtherExpenses * newQty;
                line.Shipping_and_Handling__c = perUnitShipping * newQty;
                line.Packing_and_Forwarding__c= perUnitPacking * newQty;
            }
        }
    }
}



    // Rollup totals to Proforma Invoice
    public static void updateProformaInvoiceTotals(Set<Id> piIds) {
        if (piIds.isEmpty()) return;

        List<Proforma_Invoice_Line_Item__c> lineItems = [
            SELECT Proforma_Invoice__c, CGST__c, SGST__c, IGST__c, Total_Amount_New__c
            FROM Proforma_Invoice_Line_Item__c
            WHERE Proforma_Invoice__c IN :piIds
        ];

        Map<Id, Decimal> cgstSums = new Map<Id, Decimal>();
        Map<Id, Decimal> sgstSums = new Map<Id, Decimal>();
        Map<Id, Decimal> igstSums = new Map<Id, Decimal>();
        Map<Id, Decimal> totalSums = new Map<Id, Decimal>();

        for (Proforma_Invoice_Line_Item__c li : lineItems) {
            Id piId = li.Proforma_Invoice__c;
            cgstSums.put(piId, (cgstSums.get(piId) == null ? 0 : cgstSums.get(piId)) + (li.CGST__c == null ? 0 : li.CGST__c));
            sgstSums.put(piId, (sgstSums.get(piId) == null ? 0 : sgstSums.get(piId)) + (li.SGST__c == null ? 0 : li.SGST__c));
            igstSums.put(piId, (igstSums.get(piId) == null ? 0 : igstSums.get(piId)) + (li.IGST__c == null ? 0 : li.IGST__c));
            totalSums.put(piId, (totalSums.get(piId) == null ? 0 : totalSums.get(piId)) + (li.Total_Amount_New__c == null ? 0 : li.Total_Amount_New__c));
        }

        List<Proforma_Invoice__c> piToUpdate = new List<Proforma_Invoice__c>();
        for (Id piId : piIds) {
            piToUpdate.add(new Proforma_Invoice__c(
                Id = piId,
                CGST__c = cgstSums.get(piId),
                SGST__c = sgstSums.get(piId),
                IGST__c = igstSums.get(piId),
                Total_Amount_New__c = totalSums.get(piId)
            ));
        }

        if (!piToUpdate.isEmpty()) update piToUpdate;
    }
}