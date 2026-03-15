public class SalesOrderInsertOutboundCalloutToSAP 
implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    
    private Set<Id> orderIds;
    private List<Order> ordersToUpdate;
    private List<API_LOG__c> apiLogs;
    private List<Order> failedOrders = new List<Order>();
    @TestVisible
    static Set<Id> updatedOrderIds = new Set<Id>();
    
    public SalesOrderInsertOutboundCalloutToSAP(Set<Id> orderIds) {
        this.orderIds = orderIds;
        this.ordersToUpdate = new List<Order>();
        this.apiLogs = new List<API_LOG__c>();
    }
    
    // ==================== START ====================
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('This is Start Method for Order Insert');
        return Database.getQueryLocator([
            SELECT Id, 
            Contract.SAP_Sales_Contract_Number__c, 
            Sales_Document_Type__c,Shipping_Address__c,
            Shipping_Address__r.SAP_Shipping_Address_Id__c,
            SAP_Sales_Order_Number__c,
            (SELECT Plant__c, 
             Ship_to_Party__c, Order_Document_Item_Number__c,
             Quantity, 
             Target_Quantity__c,
             Pricing_Condition__c
             FROM OrderItems)
            FROM Order
            WHERE Id IN :orderIds
        ]);
    }
    
    // ==================== EXECUTE ====================
    public void execute(Database.BatchableContext bc, List<Order> scope) {
        
        List<SAPResponseWrapper> tokenWrappers = new List<SAPResponseWrapper>();
        
        
        
        Lloyds_SFDC_Config__mdt settings = Lloyds_SFDC_Config__mdt.getInstance('Default_Config');
        String endpoint = settings.Sales_Order_Endpoint_Insert__c;
            
        Http http = new Http();
        
        
        for (Order order : scope) {
            
            String sapShippingAddressId = '';
            
            if (order.Shipping_Address__r != null) {
                sapShippingAddressId = order.Shipping_Address__r.SAP_Shipping_Address_Id__c;
            }
            
            // ============== BUILD WRAPPER ==============
            SAPSalesOrderWrapper wrapper = new SAPSalesOrderWrapper();
            wrapper.Contract_Number     = order.Contract?.SAP_Sales_Contract_Number__c ?? '';
            wrapper.Sales_Document_Type = order.Sales_Document_Type__c ?? '';
            wrapper.Address_Number = sapShippingAddressId;
            wrapper.Dummy_1 ='';
            wrapper.Dummy_2 = '';
            wrapper.Item_list = new List<SAPSalesOrderWrapper.Item>();
            
            // ============== ADD LINE ITEMS ==============
            //Integer itemValue = 20;
            for (OrderItem oi : order.OrderItems) {
                SAPSalesOrderWrapper.Item item = new SAPSalesOrderWrapper.Item();
                
                item.Document_Item_Number = oi.Order_Document_Item_Number__c ;
                item.Target_Quantity      = oi.Quantity != null ? String.valueOf(oi.Quantity) : '';
                //Pricing Conditions
                // ================= ROYALTY MAPPING =================
                item.Royalty = new List<SAPSalesOrderWrapper.PricingCondition>();
                
                if(String.isNotBlank(oi.Pricing_Condition__c)){
                    
                    try{
                        
                        Map<String,Object> parsed =
                            (Map<String,Object>)JSON.deserializeUntyped(oi.Pricing_Condition__c);
                        
                        List<Object> conds =
                            (List<Object>)parsed.get('Pricing_Conditions');
                        
                        if(conds != null){
                            
                            for(Object o : conds){
                                
                                Map<String,Object> row = (Map<String,Object>)o;
                                
                                SAPSalesOrderWrapper.PricingCondition pc =
                                    new SAPSalesOrderWrapper.PricingCondition();
                                
                                pc.Condition_type =
                                    (String)row.get('Condition_type');
                                
                                pc.Amount =
                                    (String)row.get('Amount');
                                
                                pc.Condition_Unit =
                                    (String)row.get('Condition_Unit');
                                
                                item.Royalty.add(pc);
                            }
                        }
                        
                    }catch(Exception e){
                        System.debug('Royalty parse error '+e);
                    }
                }
                
                item.Dummy_1  = '';
                item.Dummy_2  = ''; 
                
                wrapper.Item_list.add(item);
            }
            
            String sapOrderNumber = null;
            // ============== SERIALIZE ==============
            String jsonBody = JSON.serialize(wrapper.toJsonMap());
            System.debug('Full Order Insert Payload: ' + JSON.serializePretty(jsonBody));
            
            // ============== CALLOUT ==============
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:SAP_Named_Credential/' + endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(jsonBody);
            req.setTimeout(120000);
            
            
            HttpResponse res = http.send(req);
            
            // ============== RESPONSE HANDLING ==============
            List<SAPResponseWrapper> wrappers = new List<SAPResponseWrapper>();
            String status = (res.getStatusCode() == 200 || res.getStatusCode() == 201) ? 'Success' : 'Failure';
            Integer statusCode = res.getStatusCode();
            String errorMessage = (res.getStatusCode() == 200 || res.getStatusCode() == 201) ? '' : res.getBody();
            
            
            System.debug('Insert Status: ' + status);
            System.debug('Insert Status Code: ' + statusCode);
            System.debug('Insert Error Message: ' + errorMessage);
            
            
            String body = res.getBody();
            System.debug('Raw Response Body: ' + body);
            
            Boolean canParseJson = true;  // <-- Important flag
            
            //Status must be 200 or 201 for JSON parsing
            if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
                System.debug('Non-success HTTP status. JSON parsing skipped.');
                canParseJson = false;
            }
            
            
            
            //Body empty or ""
            if (String.isBlank(body) || body == '""') {
                System.debug('Empty or blank JSON response. JSON parsing skipped.');
                canParseJson = false;
            }
            
            //Body not JSON object
            else if (!body.trim().startsWith('{')) {
                System.debug('Unexpected non-JSON response. JSON parsing skipped.');
                canParseJson = false;
            }
            
            Map<String, Object> responseMap;
            Map<String, Object> salesOrderRes;
            
            //SAFE JSON PARSING BLOCK
            if (canParseJson) {
                try {
                    responseMap = (Map<String, Object>) JSON.deserializeUntyped(body);
                    System.debug('Parsed SAP Response: ' + responseMap);
                    
                    salesOrderRes =
                        (Map<String, Object>) responseMap.get('SalesOrder_Res');
                    
                    if (salesOrderRes != null
                        && salesOrderRes.containsKey('Sale_order_number')) {
                            
                            sapOrderNumber =
                                (String) salesOrderRes.get('Sale_order_number');
                            
                            ordersToUpdate.add(new Order(
                                Id = order.Id,
                                SAP_Sales_Order_Number__c = sapOrderNumber
                            ));
                            updatedOrderIds.add(order.Id);
                            System.debug('SAP Order Saved: ' + sapOrderNumber);
                        }
                }
                catch (Exception ex) {
                    System.debug('JSON parsing failed: ' + ex.getMessage());
                }
            }
            
            // ALWAYS — API LOG CREATION (Not skipped)
            String safeBody = String.isBlank(body) ? '' : body;
            
            wrappers.add(
                new SAPResponseWrapper(status, errorMessage, res.getStatusCode(), safeBody, order.Id)
            );
            
            apiLogs.add(
                SalesOrderTriggerHelper.createApiLog(
                    wrappers, jsonBody, status, errorMessage, 'POST', 'OrderInsert',
                    res.getStatusCode(), order.Id,safeBody
                )
            );
            
            if (sapOrderNumber == null) {
                failedOrders.add(
                    new Order(
                        Id = order.Id,
                        Trigger_SAP_Insert__c = false
                    )
                );
            }
        }
    }
    
    // ==================== FINISH ====================
    public void finish(Database.BatchableContext bc) {
        if (!ordersToUpdate.isEmpty()) {
            System.debug('Updating Orders in Finish');
            update ordersToUpdate;
        }
        if (!apiLogs.isEmpty()) {
            System.debug('Inserting API Logs in Finish');
            insert apiLogs;
        }
        
        if (!failedOrders.isEmpty()) {
            System.debug('Updating Trigger to SAP Insert to False');
            update failedOrders;
        }
    }
}