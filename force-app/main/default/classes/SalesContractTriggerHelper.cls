public class SalesContractTriggerHelper {
    
    // --- INSERT FLOW ---
    public static void processSAPSync(List<Contract> newList, Map<Id, Contract> oldMap) {
        Set<Id> insertIds = fetchSAPInsertIds(newList, oldMap);
        
        if (!insertIds.isEmpty()) {
            System.debug('Batch Insert Called');
            Database.executeBatch(new SalesContractInsertOutboundCalloutToSAP(insertIds), 50);
        }
    }
    
    public static Set<Id> fetchSAPInsertIds(List<Contract> contractList, Map<Id, Contract> oldMap) {
        Set<Id> conInsertIds = new Set<Id>();
        
        for (Contract con : contractList) {
            Contract oldCon = oldMap.get(con.Id);
            
            if (
                con.SAP_Sales_Contract_Number__c == null && 
                con.ContractApprovalStatus__c == 'Approved' &&
                con.Trigger_SAP_Insert__c == true && 
                oldCon.Trigger_SAP_Insert__c == false
            ) {
                System.debug('Collected Id'+con.Id);
                conInsertIds.add(con.Id);
            }
        }
        return conInsertIds;
    }
    
    
    public static API_LOG__c createApiLog(List<SAPResponseWrapper> responseWrappers, String jsonBody, String status, String errorMessage, String method, String scope, Integer statusCode, Id recordId) {
        API_LOG__c apiLog = new API_LOG__c();
        System.debug('createApiLog Method');
        System.debug('From Create API LOG --> Status '+status);
        apiLog.Status__c = status;
        apiLog.Error__c = errorMessage;
        apiLog.Request__c = jsonBody;
        //Changed
        apiLog.Response__c = (responseWrappers != null && !responseWrappers.isEmpty())
            ? responseWrappers[0].responseBody
            : null;
        apiLog.Method__c = method;
        apiLog.Scope__c = scope;
        apiLog.Status_Code__c = String.valueOf(statusCode);
        apiLog.Record_Id__c = recordId;
        return apiLog;
    }
    
    // ----------------------
    // HEADER TEXT METHOD
    // ----------------------
    public static List<SAPContractWrapper.HeaderText> buildHeaderTexts(SObject con) {
        List<SAPContractWrapper.HeaderText> listToReturn = new List<SAPContractWrapper.HeaderText>();
        
        String raw = (String) con.get('Text_Header__c');
        if (String.isBlank(raw)) {
            return listToReturn;
        }
        
        for (String entry : raw.split(';')) {
            if (String.isBlank(entry)) continue;
            
            List<String> parts = entry.split('-', 2);
            if (parts.size() != 2) continue;
            
            String textId = parts[0].trim(); // example: Z247
            
            String fieldName = 'Text_' + textId + '__c';
            
            SAPContractWrapper.HeaderText ht = new SAPContractWrapper.HeaderText();
            ht.Text_ID = textId;
            
            Object freeText = con.get(fieldName);
            ht.Text = (freeText != null) ? (String) freeText : '';
            
            listToReturn.add(ht);
        }
        
        return listToReturn;
    }
    
    public static String normalizeProductCode(String code) {
        if (String.isBlank(code)) {
            return '';
        }
        return code.replaceFirst('^0+', '');
    }
    
}