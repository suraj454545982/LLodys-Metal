public class OpportunityLineItemController {
    
    // -------------------------------
    // BLOCK CREATION IF QUOTE EXISTS
    // -------------------------------
    public static void blockOLICreationWhenQuoteExists(List<OpportunityLineItem> newList) {
        
        Set<Id> oppIds = new Set<Id>();
        for (OpportunityLineItem oli : newList) {
            if (oli.OpportunityId != null) {
                oppIds.add(oli.OpportunityId);
            }
        }
        
        if (oppIds.isEmpty()) return;
        
        Map<Id, Integer> oppIdToQuoteCount = getQuoteCounts(oppIds);
        
        for (OpportunityLineItem oli : newList) {
            Integer cnt = oppIdToQuoteCount.get(oli.OpportunityId);
            if (cnt != null && cnt > 0) {
                oli.addError('Cannot add products because a Quote already exists for this Opportunity.');
            }
        }
    }
    
    // -------------------------------
    // BLOCK DELETE IF QUOTE EXISTS
    // -------------------------------
    public static void blockOLIDeleteWhenQuoteExists(List<OpportunityLineItem> oldList) {
        
        Set<Id> oppIds = new Set<Id>();
        for (OpportunityLineItem oli : oldList) {
            if (oli.OpportunityId != null) {
                oppIds.add(oli.OpportunityId);
            }
        }
        
        if (oppIds.isEmpty()) return;
        
        Map<Id, Integer> oppIdToQuoteCount = getQuoteCounts(oppIds);
        
        for (OpportunityLineItem oli : oldList) {
            Integer cnt = oppIdToQuoteCount.get(oli.OpportunityId);
            if (cnt != null && cnt > 0) {
                oli.addError('You cannot delete this Opportunity Line Item because a Quote already exists. '
                             + 'Please delete the quote first, then remove the Opportunity Line Item.');
            }
        }
    }
    
    // -------------------------------
    // COMMON SOQL: COUNT QUOTES
    // -------------------------------
    private static Map<Id, Integer> getQuoteCounts(Set<Id> oppIds) {
        
        Map<Id, Integer> result = new Map<Id, Integer>();
        
        for (AggregateResult ar : [
            SELECT OpportunityId oppId, COUNT(Id) qCount
            FROM Quote
            WHERE OpportunityId IN :oppIds
            GROUP BY OpportunityId
        ]) {
            result.put((Id)ar.get('oppId'), (Integer)ar.get('qCount'));
        }
        
        return result;
    }
    
    public static void validateCategories(List<OpportunityLineItem> lineItems) {
        // Collect Opportunity IDs, Product IDs, and PricebookEntry IDs
        Set<Id> opportunityIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        Set<Id> pricebookEntryIds = new Set<Id>();
        
        for (OpportunityLineItem oli : lineItems) {
            opportunityIds.add(oli.OpportunityId);
            productIds.add(oli.Product2Id);
            if (oli.PricebookEntryId != null) {
                pricebookEntryIds.add(oli.PricebookEntryId);
            }
        }
        
        // Query Opportunities to get Category__c
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(
            [SELECT Id, Category__c FROM Opportunity WHERE Id IN :opportunityIds]
        );
        
        // Query Products to get Family (Category)
        Map<Id, Product2> productMap = new Map<Id, Product2>(
            [SELECT Id, Family,Name FROM Product2 WHERE Id IN :productIds]
        );
        
        // Query PricebookEntries to get Validity_Date__c
        Map<Id, PricebookEntry> pbeMap = new Map<Id, PricebookEntry>(
            [SELECT Id, Validity_Date__c, Product2Id ,ApprovalStatus_c__c,Product2.Name,Pricebook2.Validity_Date__c,Pricebook2.Name
             FROM PricebookEntry 
             WHERE Id IN :pricebookEntryIds]
        );
        
        // Validate Category__c for each OpportunityLineItem
        for (OpportunityLineItem oli : lineItems) {
            Opportunity opp = oppMap.get(oli.OpportunityId);
            Product2 prod = productMap.get(oli.Product2Id);
            PricebookEntry pbe = pbeMap.get(oli.PricebookEntryId);
            
            // ---- Pricebook (Pricebook2) Validity Date Check ----
            if (pbe != null &&
                (pbe.Pricebook2.Validity_Date__c == null ||
                 pbe.Pricebook2.Validity_Date__c < Date.today())) {
                     
                     oli.addError(
                         'Product "' + prod.Name + '" cannot be added because the Pricebook "' +
                         pbe.Pricebook2.Name + '" has an expired or missing Validity Date.'
                     );
                     continue;
                 }
            
            // ---- Pricebook Entry Validity Date Check ----
            if (pbe != null &&
                (pbe.Validity_Date__c == null ||
                 pbe.Validity_Date__c < Date.today())) {
                     
                     oli.addError(
                         'Product "' + prod.Name +
                         '" cannot be added because its Pricebook Entry has an expired or missing Validity Date.'
                     );
                     continue;
                 }
            
            // ----  Apporval Status Check for pricebook entry ----
            if (pbe != null && pbe.ApprovalStatus_c__c != 'Approved') {
                oli.addError(
                    'Product "' + prod.Name + '" cannot be added because its Pricebook Entry is not approved.'
                );
                continue;
            }
            
            // ---- Category Match Check ----
            if (opp != null && prod != null && opp.Category__c != null && prod.Family != null) {
                if (opp.Category__c != prod.Family) {
                    oli.addError('The Category on the Opportunity (' + opp.Category__c + 
                                 ') must match the Category on the Product (' + prod.Family + ').');
                }
            } else {
                // --- ️ Handle missing data cases ----
                if (opp == null || opp.Category__c == null) {
                    oli.addError('Opportunity or its Category__c is missing.');
                }
                if (prod == null || prod.Family == null) {
                    oli.addError('Product or its Category__c is missing.');
                }
            }
        }
    }
    
    // Validate Plant
    public static void validatePlant(List<OpportunityLineItem> newList,Map<Id, OpportunityLineItem> oldMap) {
        
        if (newList == null || newList.isEmpty()) return;
        
        Set<Id> oppIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        
        for (OpportunityLineItem oli : newList) {
            if (oli.OpportunityId != null) oppIds.add(oli.OpportunityId);
            if (oli.Product2Id != null) productIds.add(oli.Product2Id);
        }
        
        if (oppIds.isEmpty() || productIds.isEmpty()) return;
        
        // Fetch Opportunities
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(
            [SELECT Id, Plant_and_Shipping_Point__c FROM Opportunity WHERE Id IN :oppIds]
        );
        
        // Fetch Products
        Map<Id, Product2> productMap = new Map<Id, Product2>(
            [SELECT Id, Plant__c FROM Product2 WHERE Id IN :productIds]
        );
        
        for (OpportunityLineItem oli : newList) {
            
            Opportunity opp = oppMap.get(oli.OpportunityId);
            Product2 prod = productMap.get(oli.Product2Id);
            
            if (opp == null || prod == null) continue;
            
            //ONLY VALIDATION:
            // Product must support Opportunity Plant
            if (!String.isBlank(opp.Plant_and_Shipping_Point__c) && !String.isBlank(prod.Plant__c)) {
                
                Set<String> productPlants = new Set<String>(
                    prod.Plant__c.split(';')
                );
                
                if (!productPlants.contains(opp.Plant_and_Shipping_Point__c)) {
                    oli.addError(
                        'Selected Product is not available for the Opportunity Plant.'
                    );
                }
            }
        }
    }
}