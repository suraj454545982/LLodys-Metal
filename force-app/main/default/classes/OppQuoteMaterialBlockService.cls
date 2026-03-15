public class OppQuoteMaterialBlockService {
    
    // ==================================================================
    // 1. HEADER VALIDATION – Called from Opportunity & Quote Triggers
    // ==================================================================
    public static void validateOnInsertAndUpdate(List<SObject> records, Map<Id, SObject> oldMap) {
        if (records == null || records.isEmpty()) return;
        
        SObjectType objType = records[0].getSObjectType();
        
        // Trigger context safe handling
        Boolean isInsert = false;
        Boolean isUpdate = false;
        
        if (Trigger.isExecuting) {
            isInsert = Trigger.isInsert;
            isUpdate = Trigger.isUpdate;
        } else {
            // Called from test / service directly
            isInsert = (oldMap == null);
            isUpdate = (oldMap != null);
        }
        
        
        Map<Id, List<String>> blockedProductsMap = new Map<Id, List<String>>();
        Set<Id> sourceIds = new Set<Id>();
        
        // Step 1: Determine which IDs to check
        if (objType == Opportunity.sObjectType && isUpdate) {
            for (SObject rec : records) {
                sourceIds.add(rec.Id);
            }
        }
        else if (objType == Quote.sObjectType) {
            for (Quote q : (List<Quote>)records) {
                if (isInsert) {
                    if (q.OpportunityId != null) sourceIds.add(q.OpportunityId);
                } else {
                    if (q.Id != null) {
                        sourceIds.add(q.Id);
                    }
                }
            }
        }
        
        if (sourceIds.isEmpty()) return;
        
        // Step 2: Query blocked products (same logic for Opp & Quote insert)
        if (objType == Opportunity.sObjectType || (objType == Quote.sObjectType && isInsert)) {
            queryBlockedOLI(sourceIds, blockedProductsMap);
        }
        else if (objType == Quote.sObjectType && isUpdate) {
            queryBlockedQLI(sourceIds, blockedProductsMap);
        }
        
        // Step 3: Add errors — NOW WITH FULL PRODUCT LIST ON QUOTE INSERT TOO!
        for (SObject rec : records) {
            Id key;
            if (objType == Quote.sObjectType && isInsert) {
                key = ((Quote)rec).OpportunityId;
            } else {
                key = rec.Id;
            }
            
            if (key != null && blockedProductsMap.containsKey(key)) {
                List<String> blockedList = blockedProductsMap.get(key);
                String blockedText = String.join(blockedList, '\n• ');
                
                if (objType == Opportunity.sObjectType) {
                    // Your original Opportunity message
                    rec.addError(
                        'The following products are blocked: ' + String.join(blockedList, ', ') +
                        '. Please unblock from SAP or delete the Opportunity Line Item from Opportunity to proceed next.'
                    );
                }
                else if (objType == Quote.sObjectType) {
                    String errorMsg;
                    if (isInsert) {
                        // NOW SHOWS FULL LIST — JUST LIKE YOU WANTED!
                        errorMsg = 'Cannot create Quote because the Opportunity contains blocked product(s):\n\n' +
                            '• ' + blockedText +
                            '\n\nPlease remove blocked products from the Opportunity or unblock them in SAP.';
                    } else {
                        // Quote Update — already had bullet list
                        errorMsg = 'Cannot save Quote because it contains blocked product(s):\n\n' +
                            '• ' + blockedText +
                            '\n\nPlease delete or Unblock the Product from SAP';
                    }
                    rec.addError(errorMsg, false);
                }
            }
        }
    }
    
    // ==================================================================
    //BLOCK ON QUOTE BEFORE UPDATE WHEN STATUS → 'Accepted'
    // ==================================================================
    /**
* Prevents Quote from being Accepted if the parent Opportunity has blocked products
* This is the CORRECT and CLEANEST place to enforce this rule
*/
    public static void preventQuoteAcceptanceIfOppHasBlockedProducts(List<Quote> newQuotes, Map<Id, Quote> oldMap) {
        
        List<Quote> quotesBeingAccepted = new List<Quote>();
        
        for (Quote q : newQuotes) {
            Quote old = oldMap?.get(q.Id);
            
            // Detect change from anything → 'Accepted'
            if (q.Status == 'Accepted' 
                && (old == null || old.Status != 'Accepted')) {
                    quotesBeingAccepted.add(q);
                }
        }
        
        if (quotesBeingAccepted.isEmpty()) return;
        
        Set<Id> oppIds = new Set<Id>();
        for (Quote q : quotesBeingAccepted) {
            if (q.OpportunityId != null) {
                oppIds.add(q.OpportunityId);
            }
        }
        
        if (oppIds.isEmpty()) return;
        
        Map<Id, List<String>> blockedProductsMap = new Map<Id, List<String>>();
        queryBlockedOLI(oppIds, blockedProductsMap);
        
        for (Quote q : quotesBeingAccepted) {
            if (q.OpportunityId != null && blockedProductsMap.containsKey(q.OpportunityId)) {
                List<String> blockedList = blockedProductsMap.get(q.OpportunityId);
                
                q.addError(
                    'Cannot Accept Quote because the Opportunity contains blocked product(s):\n\n' +
                    '• ' + String.join(blockedList, '\n• ') +
                    '\n\nPlease remove blocked products from Opportunity Line Items or unblock them in SAP first.',
                    false
                );
            }
        }
    }
    
    // ==================================================================
    // PRIVATE HELPERS
    // ==================================================================
    
    private static void queryBlockedOLI(Set<Id> oppIds, Map<Id, List<String>> resultMap) {
        for (OpportunityLineItem oli : [
            SELECT OpportunityId, Product2.ProductCode, Product2.Description
            FROM OpportunityLineItem
            WHERE OpportunityId IN :oppIds
            AND Product2.Material_Blocked__c = 'Yes'
            AND Product2Id != null
        ]) {
            String prodInfo = (oli.Product2.ProductCode != null ? oli.Product2.ProductCode : 'Unknown')
                + ' - ' + (oli.Product2.Description != null ? oli.Product2.Description : '');
            
            if (!resultMap.containsKey(oli.OpportunityId)) {
                resultMap.put(oli.OpportunityId, new List<String>());
            }
            resultMap.get(oli.OpportunityId).add(prodInfo);
        }
    }
    
    private static void queryBlockedQLI(Set<Id> quoteIds, Map<Id, List<String>> resultMap) {
        for (QuoteLineItem qli : [
            SELECT QuoteId, Product2.ProductCode, Product2.Description
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
            AND Product2.Material_Blocked__c = 'Yes'
            AND Product2Id != null
        ]) {
            String prodInfo = (qli.Product2.ProductCode != null ? qli.Product2.ProductCode : 'Unknown')
                + (qli.Product2.Description != null ? ' - ' + qli.Product2.Description : '');
            
            if (!resultMap.containsKey(qli.QuoteId)) {
                resultMap.put(qli.QuoteId, new List<String>());
            }
            resultMap.get(qli.QuoteId).add(prodInfo);
        }
    }
}