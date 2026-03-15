/**
 * Handler class for ProductTrigger.
 * Contains methods to update Product IsActive based on Material_Blocked__c changes,
 * and to update related PricebookEntry IsActive fields accordingly.
 * @author Simon Christopher
 * @date 2025-11-20
 */
public class ProductTriggerHandler {
    
    private static Boolean isExecuting = false;
    
    /**
     * Before update method to set Product IsActive based on Material_Blocked__c.
     * If Material_Blocked__c is 'Yes', sets IsActive to false.
     * If 'No', sets IsActive to true.
     * @param newProducts List of updated Product2 records.
     * @param oldMap Map of old Product2 records by Id.
     */
    public void beforeUpdate(List<Product2> newProducts, Map<Id, Product2> oldMap) {
        if (isExecuting) {
            return;
        }
        isExecuting = true;
        
        for (Product2 newProduct : newProducts) {
            Product2 oldProduct = oldMap.get(newProduct.Id);
            if (newProduct.Material_Blocked__c != oldProduct.Material_Blocked__c) {
                if (newProduct.Material_Blocked__c == 'Yes') {
                    newProduct.IsActive = false;
                } else if (newProduct.Material_Blocked__c == 'No') {
                    newProduct.IsActive = true;
                }
            }
        }
        
        isExecuting = false;
    }
    
    /**
     * After update method to update PricebookEntry IsActive for changed Products.
     * Collects Products to activate/deactivate and updates their PricebookEntries.
     * @param newProducts List of updated Product2 records.
     * @param oldMap Map of old Product2 records by Id.
     */
    public void afterUpdate(List<Product2> newProducts, Map<Id, Product2> oldMap) {
        if (isExecuting) {
            return;
        }
        isExecuting = true;
        
        Set<Id> productsToDeactivate = new Set<Id>();
        Set<Id> productsToActivate = new Set<Id>();
        
        for (Product2 newProduct : newProducts) {
            Product2 oldProduct = oldMap.get(newProduct.Id);
            if (newProduct.Material_Blocked__c != oldProduct.Material_Blocked__c) {
                if (newProduct.Material_Blocked__c == 'Yes') {
                    productsToDeactivate.add(newProduct.Id);
                } else if (newProduct.Material_Blocked__c == 'No') {
                    productsToActivate.add(newProduct.Id);
                }
            }
        }
        
        if (!productsToDeactivate.isEmpty()) {
            List<PricebookEntry> entriesToDeactivate = [
                SELECT Id, IsActive 
                FROM PricebookEntry 
                WHERE Product2Id IN :productsToDeactivate
            ];
            for (PricebookEntry entry : entriesToDeactivate) {
                entry.IsActive = false;
            }
            try {
                update entriesToDeactivate;
            } catch (DmlException e) {
                // Handle error, e.g., log it or add to a custom object
                System.debug('Error updating PricebookEntries to deactivate: ' + e.getMessage());
            }
        }
        
        if (!productsToActivate.isEmpty()) {
            List<PricebookEntry> entriesToActivate = [
                SELECT Id, IsActive 
                FROM PricebookEntry 
                WHERE Product2Id IN :productsToActivate
            ];
            for (PricebookEntry entry : entriesToActivate) {
                entry.IsActive = true;
            }
            try {
                update entriesToActivate;
            } catch (DmlException e) {
                // Handle error, e.g., log it or add to a custom object
                System.debug('Error updating PricebookEntries to activate: ' + e.getMessage());
            }
        }
        
        isExecuting = false;
    }
}