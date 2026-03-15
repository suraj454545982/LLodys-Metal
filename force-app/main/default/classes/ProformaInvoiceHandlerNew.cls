public class ProformaInvoiceHandlerNew {

    
    /**
     * @description Prevents duplication of PI other than Approved one.
     */ 
    public static void preventDuplicateDraftPI(List<Proforma_Invoice__c> newPIs) {
        Set<Id> poIds = new Set<Id>();
        for (Proforma_Invoice__c pi : newPIs) {
            if (pi.Purchase_Order__c != null) poIds.add(pi.Purchase_Order__c);
        }
        if (poIds.isEmpty()) return;

        Map<Id, List<Proforma_Invoice__c>> existingPIMap = new Map<Id, List<Proforma_Invoice__c>>();
        for (Proforma_Invoice__c pi : [
            SELECT Id, Status__c, Purchase_Order__c
            FROM Proforma_Invoice__c
            WHERE Purchase_Order__c IN :poIds
              AND Status__c not in ('Approved' ,'Rejected') 
        ]) {
            if (!existingPIMap.containsKey(pi.Purchase_Order__c)) {
                existingPIMap.put(pi.Purchase_Order__c, new List<Proforma_Invoice__c>());
            }
            existingPIMap.get(pi.Purchase_Order__c).add(pi);
        }

        for (Proforma_Invoice__c newPI : newPIs) {
            if (newPI.Purchase_Order__c != null && existingPIMap.containsKey(newPI.Purchase_Order__c)) {
                newPI.addError('You cannot create a new Proforma invoice until it is approved or rejected.');
            }
        }
    }

    /**
     * Validate before insert → block PI creation if no remaining qty
     */
    public static void validateRemainingQty(List<Proforma_Invoice__c> newPiList) {
        if (newPiList == null || newPiList.isEmpty()) return;

        Set<Id> poIds = new Set<Id>();
        for (Proforma_Invoice__c pi : newPiList) {
            if (pi.Purchase_Order__c != null) poIds.add(pi.Purchase_Order__c);
        }
        if (poIds.isEmpty()) return;

        Map<Id, List<Purchase_Order_Line_Item__c>> poToLines = new Map<Id, List<Purchase_Order_Line_Item__c>>();
        for (Purchase_Order_Line_Item__c line : [
            SELECT Id, Product__c, Quantity__c, Purchase_Order__c
            FROM Purchase_Order_Line_Item__c
            WHERE Purchase_Order__c IN :poIds 
        ]) {
            if (!poToLines.containsKey(line.Purchase_Order__c)) poToLines.put(line.Purchase_Order__c, new List<Purchase_Order_Line_Item__c>());
            poToLines.get(line.Purchase_Order__c).add(line);
        }

        // Already invoiced quantities
        List<Proforma_Invoice_Line_Item__c> prevPiLines = [
            SELECT Product__c, Quantity__c, Proforma_Invoice__r.Purchase_Order__c
            FROM Proforma_Invoice_Line_Item__c
            WHERE Proforma_Invoice__r.Purchase_Order__c IN :poIds  AND Proforma_Invoice__r.Status__c = 'Approved'
        ];

        Map<Id, Map<Id, Decimal>> alreadyInvoicedByPO = new Map<Id, Map<Id, Decimal>>();
        for (Proforma_Invoice_Line_Item__c line : prevPiLines) {
            Id poId = line.Proforma_Invoice__r.Purchase_Order__c;
            if (!alreadyInvoicedByPO.containsKey(poId)) alreadyInvoicedByPO.put(poId, new Map<Id, Decimal>());
            Map<Id, Decimal> productQty = alreadyInvoicedByPO.get(poId);
            Decimal curr = productQty.containsKey(line.Product__c) ? productQty.get(line.Product__c) : 0;
            productQty.put(line.Product__c, curr + (line.Quantity__c != null ? line.Quantity__c : 0));
        }

        // Validate each PI
        for (Proforma_Invoice__c pi : newPiList) {
            if (pi.Purchase_Order__c == null) continue;
            List<Purchase_Order_Line_Item__c> poLines = poToLines.get(pi.Purchase_Order__c);
            if (poLines == null || poLines.isEmpty()) {
                pi.addError('No PO Line Items found for the selected PO.');
                continue;
            }

            Map<Id, Decimal> invoicedMap = alreadyInvoicedByPO.containsKey(pi.Purchase_Order__c)
                ? alreadyInvoicedByPO.get(pi.Purchase_Order__c)
                : new Map<Id, Decimal>();

            Boolean hasRemaining = false;
            for (Purchase_Order_Line_Item__c poLine : poLines) {
                Decimal poQty = poLine.Quantity__c != null ? poLine.Quantity__c : 0;
                Decimal usedQty = invoicedMap.containsKey(poLine.Product__c) ? invoicedMap.get(poLine.Product__c) : 0;
                
                   system.debug('poQty-->'+poQty);
                system.debug('usedQty-->'+usedQty);
                if (poQty - usedQty > 0) {
                    hasRemaining = true;
                    break;
                }
            }

            if (!hasRemaining) pi.addError('All quantities in the selected PO are already invoiced. Cannot create new PI.');
        }
    }

    /**
     * Map Purchase Order to Proforma Invoice
     */
    public static void mapPOtoPI(List<Proforma_Invoice__c> newPiList) {
        if (newPiList == null || newPiList.isEmpty()) return;

        Set<Id> poIds = new Set<Id>();
        for (Proforma_Invoice__c pi : newPiList) {
            if (pi.Purchase_Order__c != null) poIds.add(pi.Purchase_Order__c);
        }
        if (poIds.isEmpty()) return;

        Map<Id, Purchase_Order__c> poMap = new Map<Id, Purchase_Order__c>(
            [SELECT Id, Name, PO_Approval_Status__c
             FROM Purchase_Order__c
             WHERE Id IN :poIds AND PO_Approval_Status__c = 'Approved']
        );

        Map<Id, List<Purchase_Order_Line_Item__c>> poToLines = new Map<Id, List<Purchase_Order_Line_Item__c>>();
        for (Purchase_Order_Line_Item__c line : [
            SELECT Id, Product__c, Quantity__c, Sales_Price__c, Purchase_Order__c,
                   Discount__c, Other_expenses__c, Packing_and_Forwarding__c,
                   Shipping_and_Handling__c, Freight__c, Product__r.GST_Percentage__c,GST_Tax_Percentage__c
            FROM Purchase_Order_Line_Item__c
            WHERE Purchase_Order__c IN :poIds
        ]) {
            if (!poToLines.containsKey(line.Purchase_Order__c)) poToLines.put(line.Purchase_Order__c, new List<Purchase_Order_Line_Item__c>());
            poToLines.get(line.Purchase_Order__c).add(line);
        }

        List<Proforma_Invoice_Line_Item__c> piLinesToInsert = new List<Proforma_Invoice_Line_Item__c>();

        for (Proforma_Invoice__c pi : newPiList) {
            if (pi.hasErrors() || pi.Purchase_Order__c == null) continue;

            Purchase_Order__c po = poMap.get(pi.Purchase_Order__c);
            if (po == null) {
                pi.addError('Referenced PO is not Approved.');
                continue;
            }

            List<Purchase_Order_Line_Item__c> poLines = poToLines.get(po.Id);
            if (poLines == null || poLines.isEmpty()) {
                pi.addError('No PO Line Items found for PO ' + po.Id);
                continue;
            }

            // Previous PI Lines
            List<Proforma_Invoice_Line_Item__c> prevPiLines = [
                SELECT Product__c, Quantity__c
                FROM Proforma_Invoice_Line_Item__c
                WHERE Proforma_Invoice__r.Purchase_Order__c = :po.Id
                AND Proforma_Invoice__c != :pi.Id     AND Proforma_Invoice__r.Status__c = 'Approved'
            ];

            Map<Id, Decimal> alreadyInvoicedMap = new Map<Id, Decimal>();
            for (Proforma_Invoice_Line_Item__c prevLine : prevPiLines) {
                Decimal prevQty = alreadyInvoicedMap.containsKey(prevLine.Product__c) 
                    ? alreadyInvoicedMap.get(prevLine.Product__c) : 0;
                alreadyInvoicedMap.put(prevLine.Product__c, prevQty + (prevLine.Quantity__c != null ? prevLine.Quantity__c : 0));
            }

            Boolean isFirstPI = prevPiLines.isEmpty();

            for (Purchase_Order_Line_Item__c poli : poLines) {
                Decimal poQty = (poli.Quantity__c != null) ? poli.Quantity__c : 0;
                Decimal unitPrice = (poli.Sales_Price__c != null) ? poli.Sales_Price__c : 0;

                Decimal lineQty = isFirstPI ? poQty : poQty - (alreadyInvoicedMap.containsKey(poli.Product__c) ? alreadyInvoicedMap.get(poli.Product__c) : 0);
                if (lineQty <= 0) continue;

                // Per-unit discount calculation
                /*Decimal totalDiscount = 0;
                if (poli.Discount__c != null && poQty > 0) {
                    Decimal discountPerUnit = poli.Discount__c / poQty;
                    totalDiscount = discountPerUnit * lineQty;
                }*/
                
                

                  // Calculate per-unit values for Discount, Freight, etc.
                //Decimal perUnitDiscount = (poli.Discount__c != null && poQty > 0) ? poli.Discount__c / poQty : 0;
                Decimal perUnitFreight = (poli.Freight__c != null && poQty > 0) ? poli.Freight__c / poQty : 0;
                Decimal perUnitOtherExpenses = (poli.Other_Expenses__c != null && poQty > 0) ? poli.Other_Expenses__c / poQty : 0;
                Decimal perUnitShipping = (poli.Shipping_and_Handling__c != null && poQty > 0) ? poli.Shipping_and_Handling__c / poQty : 0;
                Decimal perUnitPacking = (poli.Packing_and_Forwarding__c != null && poQty > 0) ? poli.Packing_and_Forwarding__c / poQty : 0;
                
                  // Calculate proportional values for Sales Contract Line Item
                //Decimal discount = perUnitDiscount * lineQty;
                Decimal freight = perUnitFreight * lineQty;
                Decimal otherExpenses = perUnitOtherExpenses * lineQty;
                Decimal shipping = perUnitShipping * lineQty;
                Decimal packing = perUnitPacking * lineQty;


                Proforma_Invoice_Line_Item__c newPiLine = new Proforma_Invoice_Line_Item__c(
                    Proforma_Invoice__c = pi.Id,
                    Product__c          = poli.Product__c,
                    Quantity__c         = lineQty,
                    Freight__c = freight,
                    Other_expenses__c =otherExpenses,
                    Packing_and_Forwarding__c =packing,
                    Shipping_and_Handling__c =shipping,
                    Discount__c   = poli.Discount__c,
                    Sales_Price__c      = unitPrice,
                    GST_Tax_Percentage__c = poli.GST_Tax_Percentage__c
                  
                );

                piLinesToInsert.add(newPiLine);
            }
        }

        if (!piLinesToInsert.isEmpty()) insert piLinesToInsert;
    }

    /**
     * Validation on PI Approval - Prevent exceeding PO qty
     */
    public static void validateApprovalQuantities(List<Proforma_Invoice__c> piList) {
        Set<Id> poIds = new Set<Id>();
        for (Proforma_Invoice__c pi : piList) {
            if (pi.Purchase_Order__c != null) poIds.add(pi.Purchase_Order__c);
        }
        if (poIds.isEmpty()) return;

        Map<Id, List<Purchase_Order_Line_Item__c>> poToLines = new Map<Id, List<Purchase_Order_Line_Item__c>>();
        for (Purchase_Order_Line_Item__c line : [
            SELECT Id, Product__c, Quantity__c, Purchase_Order__c, Discount__c, Other_expenses__c, Packing_and_Forwarding__c,
                   Shipping_and_Handling__c, Freight__c, Product__r.GST_Percentage__c
            FROM Purchase_Order_Line_Item__c
            WHERE Purchase_Order__c IN :poIds
        ]) {
            if (!poToLines.containsKey(line.Purchase_Order__c)) poToLines.put(line.Purchase_Order__c, new List<Purchase_Order_Line_Item__c>());
            poToLines.get(line.Purchase_Order__c).add(line);
        }

        List<Proforma_Invoice_Line_Item__c> allPiLines = [
            SELECT Proforma_Invoice__c, Product__c, Quantity__c, Proforma_Invoice__r.Purchase_Order__c
            FROM Proforma_Invoice_Line_Item__c
            WHERE Proforma_Invoice__r.Purchase_Order__c IN :poIds   AND Proforma_Invoice__r.Status__c = 'Approved'
        ];

        Map<Id, Map<Id, Decimal>> poToProductQty = new Map<Id, Map<Id, Decimal>>();
        for (Proforma_Invoice_Line_Item__c line : allPiLines) {
            Id poId = line.Proforma_Invoice__r.Purchase_Order__c;
            if (!poToProductQty.containsKey(poId)) poToProductQty.put(poId, new Map<Id, Decimal>());
            Map<Id, Decimal> productQty = poToProductQty.get(poId);
            Decimal currentQty = productQty.containsKey(line.Product__c) ? productQty.get(line.Product__c) : 0;
            productQty.put(line.Product__c, currentQty + (line.Quantity__c != null ? line.Quantity__c : 0));
        }

        for (Id poId : poToLines.keySet()) {
            List<Purchase_Order_Line_Item__c> poLines = poToLines.get(poId);
            Map<Id, Decimal> productQty = poToProductQty.containsKey(poId) ? poToProductQty.get(poId) : new Map<Id, Decimal>();

            for (Purchase_Order_Line_Item__c poLine : poLines) {
                Decimal poQty = (poLine.Quantity__c != null) ? poLine.Quantity__c : 0;
                Decimal invoicedQty = productQty.containsKey(poLine.Product__c) ? productQty.get(poLine.Product__c) : 0;

                if (invoicedQty > poQty) {
                    for (Proforma_Invoice__c pi : piList) {
                        if (pi.Purchase_Order__c == poId) {
                            pi.addError(
                                'Total PI Quantity for product ' +
                                ' exceeds PO Quantity. PO Qty: ' + poQty + ', Invoiced Qty: ' + invoicedQty
                            );
                        }
                    }
                }
            }
        }
    }
}