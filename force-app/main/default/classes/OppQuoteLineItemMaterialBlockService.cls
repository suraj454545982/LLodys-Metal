public class OppQuoteLineItemMaterialBlockService {
    
    /**
     * Global method called from BOTH OpportunityLineItem & QuoteLineItem triggers
     * Blocks insert/update if the selected Product has Material_Blocked__c = 'Yes'
     * Uses your EXACT original error messages
     */
    public static void preventAddingOrUpdatingBlockedProducts(List<SObject> newLineItems, Boolean isInsert) {
        if (newLineItems == null || newLineItems.isEmpty()) return;
        
        SObjectType lineType = newLineItems[0].getSObjectType();
        Set<Id> productIds = new Set<Id>();
        
        // Collect all Product2Id from both OLI and QLI
        for (SObject line : newLineItems) {
            Id prodId = (Id)line.get('Product2Id');
            if (prodId != null) {
                productIds.add(prodId);
            }
        }
        
        if (productIds.isEmpty()) return;
        
        // Query only blocked products
        Map<Id, Product2> blockedProducts = new Map<Id, Product2>([
            SELECT Id, ProductCode, Description
            FROM Product2
            WHERE Id IN :productIds
              AND Material_Blocked__c = 'Yes'
        ]);
        
        if (blockedProducts.isEmpty()) return;
        
        for (SObject line : newLineItems) {
            Id prodId = (Id)line.get('Product2Id');
            if (prodId != null && blockedProducts.containsKey(prodId)) {
                Product2 p = blockedProducts.get(prodId);
                
                String productLabel = (String.isNotBlank(p.ProductCode) ? p.ProductCode : '')
                                    + (String.isNotBlank(p.Description) ? ' - ' + p.Description : '');
                
                String errorMessage;
                
                if (isInsert) {
                    errorMessage = productLabel + ' is blocked. Please remove this or unblock it from SAP before adding ' +
                                  (lineType == OpportunityLineItem.sObjectType ? 'in Opportunity.' : 'to the Quote.');
                } else {
                    errorMessage = 'You cannot ' + 
                                  (lineType == OpportunityLineItem.sObjectType ? 'Update this Line Item' : 'update this Quote Line Item') +
                                  ', Product ' + productLabel + ' is Blocked';
                }
                
                line.addError(errorMessage, false);
            }
        }
    }
}