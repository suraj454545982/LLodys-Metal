public class MaterialBlockLineItemService {

    // ========================================================================
    // MAIN METHOD — CALL FROM BEFORE UPDATE & BEFORE DELETE ONLY
    // Fully supports DELETE (uses oldMap when Trigger.new is null)
    // ========================================================================
    public static void preventLineItemChanges(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        
        System.debug('=== MaterialBlockLineItemService.preventLineItemChanges() START ===');
        System.debug('Trigger Operation: ' + Trigger.operationType);

        // CRITICAL: NEVER RUN ON INSERT — would block line creation from Quote → PO
        if (Trigger.isInsert) {
            System.debug('INSERT detected → Skipping all blocking logic (this is correct!)');
            return;
        }

        // DETERMINE WHICH RECORDS TO PROCESS
        List<SObject> recordsToProcess;

        if (Trigger.isDelete) {
            // On delete: Trigger.new is NULL → must use oldMap
            if (oldMap == null || oldMap.isEmpty()) {
                System.debug('DELETE but oldMap is empty → nothing to process');
                return;
            }
            recordsToProcess = oldMap.values();
            System.debug('DELETE operation → Processing ' + recordsToProcess.size() + ' records from oldMap');
        } else {
            // On update: use newRecords
            if (newRecords == null || newRecords.isEmpty()) {
                System.debug('UPDATE but newRecords is empty → exiting');
                return;
            }
            recordsToProcess = newRecords;
            System.debug('UPDATE operation → Processing ' + recordsToProcess.size() + ' records from newRecords');
        }

        SObjectType lineType = recordsToProcess[0].getSObjectType();
        System.debug('Line Item Object Type: ' + lineType);

        // 1. DOCUMENT FREEZE: Block any change if header has blocked product
        blockIfDocumentIsFrozen(recordsToProcess, lineType);

        // 2. DIRECT BLOCK: Block change if the line's own product is blocked
        blockDirectAccessToBlockedProductLine(recordsToProcess, lineType);

        System.debug('=== MaterialBlockLineItemService.preventLineItemChanges() END ===');
    }

    // ─────────────────────────────────────────────────────────────────────
    // 1. DOCUMENT FREEZE: Cannot edit/delete ANY line if header has blocked product
    // ─────────────────────────────────────────────────────────────────────
    private static void blockIfDocumentIsFrozen(List<SObject> lines, SObjectType lineType) {
        System.debug('→ Checking Document Freeze...');

        Set<Id> headerIds = new Set<Id>();
        for (SObject line : lines) {
            Id headerId = getHeaderId(line, lineType);
            if (headerId != null) headerIds.add(headerId);
        }
        if (headerIds.isEmpty()) {
            System.debug('No header IDs found → skipping freeze check');
            return;
        }

        Set<Id> frozenHeaders = new Set<Id>();

        // Check all 4 document types for any blocked product
        for (AggregateResult ar : [SELECT Purchase_Order__c h FROM Purchase_Order_Line_Item__c 
                                   WHERE Purchase_Order__c IN :headerIds AND Product__r.Material_Blocked__c = 'Yes' 
                                   GROUP BY Purchase_Order__c]) {
            frozenHeaders.add((Id)ar.get('h'));
        }
        for (AggregateResult ar : [SELECT Proforma_Invoice__c h FROM Proforma_Invoice_Line_Item__c 
                                   WHERE Proforma_Invoice__c IN :headerIds AND Product__r.Material_Blocked__c = 'Yes' 
                                   GROUP BY Proforma_Invoice__c]) {
            frozenHeaders.add((Id)ar.get('h'));
        }
        for (AggregateResult ar : [SELECT Contract__c h FROM Sales_Contract_Line_Item__c 
                                   WHERE Contract__c IN :headerIds AND Product__r.Material_Blocked__c = 'Yes' 
                                   GROUP BY Contract__c]) {
            frozenHeaders.add((Id)ar.get('h'));
        }
        for (AggregateResult ar : [SELECT OrderId h FROM OrderItem 
                                   WHERE OrderId IN :headerIds AND Product2.Material_Blocked__c = 'Yes' 
                                   GROUP BY OrderId]) {
            frozenHeaders.add((Id)ar.get('h'));
        }

        System.debug('Frozen Headers Count: ' + frozenHeaders.size());
        if (frozenHeaders.isEmpty()) return;

        String action = Trigger.isDelete ? 'delete' : 'modify';
        String lineLabel = lineType.getDescribe().getLabel();
        String headerLabel = getHeaderObjectLabel(lineType);

        for (SObject line : lines) {
            Id headerId = getHeaderId(line, lineType);
            if (headerId != null && frozenHeaders.contains(headerId)) {
                System.debug('BLOCKED (Document Freeze): ' + action + ' on ' + headerId);
                line.addError(
                    'Cannot ' + action + ' this ' + lineLabel + '.\n\n' +
                    'The ' + headerLabel + ' is FROZEN because it contains one or more blocked products.\n\n' +
                    'Remove or unblock all blocked products before making changes.',
                    false
                );
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // 2. DIRECT BLOCK: Cannot edit/delete line if its own product is blocked
    // ─────────────────────────────────────────────────────────────────────
    private static void blockDirectAccessToBlockedProductLine(List<SObject> lines, SObjectType lineType) {
        System.debug('→ Checking direct blocked product access...');

        Set<Id> productIds = new Set<Id>();
        for (SObject line : lines) {
            Id prodId = getProductId(line, lineType);
            if (prodId != null) productIds.add(prodId);
        }
        if (productIds.isEmpty()) return;

        Map<Id, Product2> blockedProducts = new Map<Id, Product2>([
            SELECT Id, ProductCode, Description
            FROM Product2
            WHERE Id IN :productIds AND Material_Blocked__c = 'Yes'
        ]);

        System.debug('Blocked products in transaction: ' + blockedProducts.size());
        if (blockedProducts.isEmpty()) return;

        String action = Trigger.isDelete ? 'delete' : 'modify';

        for (SObject line : lines) {
            Id prodId = getProductId(line, lineType);
            if (prodId != null && blockedProducts.containsKey(prodId)) {
                Product2 p = blockedProducts.get(prodId);
                System.debug('BLOCKED (Direct): ' + action + ' blocked product: ' + p.ProductCode);
                line.addError(
                    'Cannot ' + action + ' this line item.\n\n' +
                    'Product is BLOCKED:\n' +
                    p.ProductCode + ' - ' + p.Description + '\n' +
                    'Material Blocked = Yes\n\n' +
                    'Contact administrator to unblock the product.',
                    false
                );
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // HELPER METHODS
    // ─────────────────────────────────────────────────────────────────────
    private static Id getProductId(SObject line, SObjectType objType) {
        return (objType == OrderItem.sObjectType)
            ? (Id)line.get('Product2Id')
            : (Id)line.get('Product__c');
    }

    private static Id getHeaderId(SObject line, SObjectType objType) {
        if (objType == Purchase_Order_Line_Item__c.sObjectType)      return (Id)line.get('Purchase_Order__c');
        if (objType == Proforma_Invoice_Line_Item__c.sObjectType)   return (Id)line.get('Proforma_Invoice__c');
        if (objType == Sales_Contract_Line_Item__c.sObjectType)     return (Id)line.get('Contract__c');
        if (objType == OrderItem.sObjectType)                       return (Id)line.get('OrderId');
        return null;
    }

    private static String getHeaderObjectLabel(SObjectType lineType) {
        if (lineType == Purchase_Order_Line_Item__c.sObjectType)      return 'Purchase Order';
        if (lineType == Proforma_Invoice_Line_Item__c.sObjectType)   return 'Proforma Invoice';
        if (lineType == Sales_Contract_Line_Item__c.sObjectType)     return 'Contract';
        if (lineType == OrderItem.sObjectType)                       return 'Sales Order';
        return 'Document';
    }
}