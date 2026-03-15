public class SalesContractLineItemHelper {
    
    // --- Called from Trigger ---
    public static void processLineItemChange(List<Sales_Contract_Line_Item__c> newList, Map<Id, Sales_Contract_Line_Item__c> oldMap) {
        Set<Id> contractIdsToUpdate = fetchSAPUpdateIds(newList, oldMap);
        
        if (!contractIdsToUpdate.isEmpty()) {
            Database.executeBatch(new SalesContractUpdateOutboundCalloutToSAP(contractIdsToUpdate), 50);
        }
    }
    
    
    // --- Fetch Contract IDs that require SAP Update ---
    public static Set<Id> fetchSAPUpdateIds(List<Sales_Contract_Line_Item__c> newList, Map<Id, Sales_Contract_Line_Item__c> oldMap) {
        Set<Id> contractIdsToUpdate = new Set<Id>();
        
        for (Sales_Contract_Line_Item__c li : newList) {
            Sales_Contract_Line_Item__c oldLi = oldMap.get(li.Id);
            
            // Skip if no contract
            if (li.Contract__c == null) continue;
            
            // Skip if Contract is not yet in SAP (VERY IMPORTANT)
            Contract parentCon = [
                SELECT SAP_Sales_Contract_Number__c 
                FROM Contract WHERE Id = :li.Contract__c 
                LIMIT 1
            ];
            
            if (parentCon.SAP_Sales_Contract_Number__c == null) {
                continue; // Do NOT send update if Contract not created in SAP yet
            }
            
            if (li.Reason_for_Rejection__c != oldLi.Reason_for_Rejection__c) {
                
                contractIdsToUpdate.add(li.Contract__c);
            }
        }
        
        return contractIdsToUpdate;
    }
    
    // ----------------------
    // LINE ITEM TEXT METHOD
    // ----------------------
    public static List<SAPContractWrapper.LineitemText> buildLineItemTexts(SObject cli) {
        List<SAPContractWrapper.LineitemText> listToReturn = new List<SAPContractWrapper.LineitemText>();
        
        String raw = (String) cli.get('Text_Item__c');
        if (String.isBlank(raw)) {
            return listToReturn;
        }
        
        for (String entry : raw.split(';')) {
            if (String.isBlank(entry)) continue;
            
            String textId = entry.trim();   // direct value now
            
            String fieldName = 'Text_' + textId + '__c';
            
            SAPContractWrapper.LineitemText lt = new SAPContractWrapper.LineitemText();
            lt.Text_ID = textId;
            
            Object freeText = cli.get(fieldName);
            lt.Text = (freeText != null) ? (String) freeText : '';
            
            listToReturn.add(lt);
        }
        
        return listToReturn;
    }
}