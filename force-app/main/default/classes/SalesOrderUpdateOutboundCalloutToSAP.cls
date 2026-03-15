public class SalesOrderUpdateOutboundCalloutToSAP 
    implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {

    private Set<Id> orderIds;
    private List<Order> ordersToUpdate;
    private List<API_LOG__c> apiLogs;

    public SalesOrderUpdateOutboundCalloutToSAP(Set<Id> orderIds) {
        this.orderIds = orderIds;
        this.ordersToUpdate = new List<Order>();
        this.apiLogs = new List<API_LOG__c>();
    }

    // ==================== START ====================
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('This is Start Method for Order Update');
        return Database.getQueryLocator([
            SELECT Id, SAP_Sales_Order_Number__c,Shipping_Address__c,
            Shipping_Address__r.SAP_Shipping_Address_Id__c,
                   (SELECT Quantity, Product_Code__c, Reason_for_Rejection__c , Plant__c,Order_Document_Item_Number__c
                    FROM OrderItems)
            FROM Order
            WHERE Id IN :orderIds
        ]);
    }

    // ==================== EXECUTE ====================
    public void execute(Database.BatchableContext bc, List<Order> scope) {
        List<SAPResponseWrapper> tokenWrappers = new List<SAPResponseWrapper>();

       
        Lloyds_SFDC_Config__mdt settings = Lloyds_SFDC_Config__mdt.getInstance('Default_Config');
        String endpoint = settings.Sales_Order_Endpoint_Update__c;
        
        Http http = new Http();

        for (Order order : scope) {
            
            String sapShippingAddressId = '';
            
            if (order.Shipping_Address__r != null) {
                sapShippingAddressId = order.Shipping_Address__r.SAP_Shipping_Address_Id__c;
            }
            
            // ============== BUILD WRAPPER ==============
            SAPSalesOrderUpdateWrapper wrapper = new SAPSalesOrderUpdateWrapper();
            wrapper.Sale_Order_Number = order.SAP_Sales_Order_Number__c ?? '';
            wrapper.Address_Number = sapShippingAddressId;
            wrapper.Dummy1 = '';
            wrapper.Dummy2 = '';
            
            // ============== ADD LINE ITEMS ==============
            //Integer itemCounter = 20;
            for (OrderItem oi : order.OrderItems) {
                SAPSalesOrderUpdateWrapper.Item item = new SAPSalesOrderUpdateWrapper.Item();
                item.Item = oi.Order_Document_Item_Number__c ?? '';
                item.Material = oi.Product_Code__c ?? '';
                item.Reason_for_Rejection = oi.Reason_for_Rejection__c ?? '';
                item.Qty = oi.Quantity != null ? String.valueOf(oi.Quantity) : '';
                item.Plant = oi.Plant__c ?? '';
                wrapper.SalesOrderUpdate_item_list.add(item);
                //itemCounter += 10;
            }

            // ============== SERIALIZE ==============
            String jsonBody = JSON.serialize(wrapper.toJsonMap());
            System.debug('Full Order Update Payload: ' + JSON.serializePretty(jsonBody));

            // ============== CALLOUT ==============
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:SAP_Named_Credential/' + endpoint); // Assumes a config field for update endpoint
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(jsonBody);
            req.setTimeout(120000);

            HttpResponse res = http.send(req);

            // ============== RESPONSE HANDLING ==============
            List<SAPResponseWrapper> wrappers = new List<SAPResponseWrapper>();
            String status = (res.getStatusCode() == 200 || res.getStatusCode() == 201) ? 'SUCCESS' : 'ERROR';
            Integer statusCode = res.getStatusCode();
            String errorMessage = (res.getStatusCode() == 200 || res.getStatusCode() == 201) ? '' : res.getBody();

            System.debug('Update Status: ' + status);
            System.debug('Update Status Code: ' + statusCode);
            System.debug('Update Error Message: ' + errorMessage);

            wrappers.add(new SAPResponseWrapper(status, errorMessage, res.getStatusCode(), res.getBody(), order.Id));
            apiLogs.add(SalesOrderTriggerHelper.createApiLog(wrappers, jsonBody, status, errorMessage, 'POST', 'OrderUpdate', res.getStatusCode(), order.Id,res.getBody()));
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
    }
}