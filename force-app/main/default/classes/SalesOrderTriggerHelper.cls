public class SalesOrderTriggerHelper {
    
    //Testing Bypass
    public static Boolean bypassTrigger = false;
    
    public static void processSAPSync(List<Order> newList, Map<Id, Order> oldMap) {
        
        //Testing Bypass Return
        if (Test.isRunningTest() && bypassTrigger) {
            return;
        }
        
        Set<Id> insertIds = fetchSAPInsertIds(newList, oldMap);
        
        if (!insertIds.isEmpty()) {
            System.debug('Batch Insert Called for Orders: ' + insertIds);
            Database.executeBatch(new SalesOrderInsertOutboundCalloutToSAP(insertIds), 50);
        }
    }
    
    public static Set<Id> fetchSAPInsertIds(List<Order> orderList, Map<Id, Order> oldMap) {
        Set<Id> ordInsertIds = new Set<Id>();
        Set<Id> contractIds = new Set<Id>();
        
        // Step 1: Collect all related Contract Ids
        for (Order ord : orderList) {
            if (ord.ContractId != null) {
                contractIds.add(ord.ContractId);
            }
        }
        
        // Step 2: Query Contracts and store SAP numbers in a map
        Map<Id, Contract> contractMap = new Map<Id, Contract>(
            [SELECT Id, SAP_Sales_Contract_Number__c FROM Contract WHERE Id IN :contractIds]
        );
        
        // Step 3: Loop through orders and filter
        for (Order ord : orderList) {
            if (oldMap != null && oldMap.containsKey(ord.Id)) {
                Order oldOrd = oldMap.get(ord.Id);
                Contract relatedContract = contractMap.get(ord.ContractId);
                
                if (
                    ord.SAP_Sales_Order_Number__c == null && 
                    ord.Sales_Order_Approval__c == 'Approved' &&
                    ord.Trigger_SAP_Insert__c == true && 
                    oldOrd.Trigger_SAP_Insert__c == false && 
                    relatedContract != null &&
                    relatedContract.SAP_Sales_Contract_Number__c != null
                ) {
                    System.debug('Eligible Order for SAP Insert: ' + ord.Id);
                    ordInsertIds.add(ord.Id);
                }
            }
        }
        
        return ordInsertIds;
    }
   
    
    public static API_LOG__c createApiLog(List<SAPResponseWrapper> responseWrappers, String jsonBody, String status, String errorMessage, String method, String scope, Integer statusCode, Id recordId, String responseBody) {
        API_LOG__c apiLog = new API_LOG__c();
        System.debug('createApiLog Method');
        System.debug('From Create API LOG --> Status '+status);
        apiLog.Status__c = status;
        apiLog.Error__c = errorMessage;
        apiLog.Request__c = jsonBody;
        apiLog.Response__c = responseBody;
        apiLog.Method__c = method;
        apiLog.Scope__c = scope;
        apiLog.Status_Code__c = String.valueOf(statusCode);
        apiLog.Record_Id__c = recordId;
        return apiLog;
    }
}