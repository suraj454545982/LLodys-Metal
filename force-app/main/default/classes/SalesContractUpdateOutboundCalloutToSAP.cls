public class SalesContractUpdateOutboundCalloutToSAP implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    private Set<Id> contractIds;
    private List<Contract> contractsToUpdate; // Optional: if you need to update any fields post-response
    private List<API_LOG__c> apiLogs;
    
    public SalesContractUpdateOutboundCalloutToSAP(Set<Id> contractIds) {
        this.contractIds = contractIds;
        this.contractsToUpdate = new List<Contract>();
        this.apiLogs = new List<API_LOG__c>();
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('Starting Contract Update Batch');
        return Database.getQueryLocator([
            SELECT Id, SAP_Sales_Contract_Number__c
            FROM Contract
            WHERE Id IN :contractIds
            AND SAP_Sales_Contract_Number__c != null
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<Contract> scope) {
        
        List<SAPResponseWrapper> tokenWrappers = new List<SAPResponseWrapper>();
        
        
        Lloyds_SFDC_Config__mdt settings = Lloyds_SFDC_Config__mdt.getInstance('Default_Config');
        String endpoint = settings.Sales_Contract_Endpoint_Update__c;
        Http http = new Http();
        
        // Query Line Items for Update (only those with Reason_for_Rejection__c or Quantity__c changes)
        Map<Id, List<Sales_Contract_Line_Item__c>> contractLineItemsMap = new Map<Id, List<Sales_Contract_Line_Item__c>>();
        for (Sales_Contract_Line_Item__c cli : [
            SELECT Id, Contract__c, Product_Code__c, Reason_for_Rejection__c, Quantity__c,Contract_Document_Item_Number__c
            FROM Sales_Contract_Line_Item__c
            WHERE Contract__c IN :scope
        ]) {
            if (!contractLineItemsMap.containsKey(cli.Contract__c)) {
                contractLineItemsMap.put(cli.Contract__c, new List<Sales_Contract_Line_Item__c>());
            }
            contractLineItemsMap.get(cli.Contract__c).add(cli);
        }
        
        for (Contract con : scope) {
            if (!contractLineItemsMap.containsKey(con.Id) || contractLineItemsMap.get(con.Id).isEmpty()) {
                // No line items to update for this contract
                System.debug('No updateable line items for Contract: ' + con.Id);
                apiLogs.add(SalesContractTriggerHelper.createApiLog(
                    new List<SAPResponseWrapper>{new SAPResponseWrapper('SKIPPED', 'No line items with updates', 200, null, con.Id)},
                    null, 'Skipped', 'No data to update', 'POST', 'Contract Update', 200, con.Id
                ));
                continue;
            }
            
            SAPContractUpdateWrapper wrapper = new SAPContractUpdateWrapper();
            wrapper.Contract_Number = con.SAP_Sales_Contract_Number__c;
            
            wrapper.SalesContractUpdate_item_list = new List<SAPContractUpdateWrapper.UpdateItem>();
            
            //Added for Items -  10 Interval
            for (Sales_Contract_Line_Item__c cli : contractLineItemsMap.get(con.Id)) {
                SAPContractUpdateWrapper.UpdateItem item = new SAPContractUpdateWrapper.UpdateItem();
                //item.Item = cli.Quantity__c != null ? String.valueOf(cli.Quantity__c) : '';
                
                //Interval of 10
                item.Item = cli.Contract_Document_Item_Number__c != null ? cli.Contract_Document_Item_Number__c : '';
                
                item.Material = cli.Product_Code__c != null ? cli.Product_Code__c : '';
                item.Reason_for_Rejection = cli.Reason_for_Rejection__c != null ? cli.Reason_for_Rejection__c : '';
                wrapper.SalesContractUpdate_item_list.add(item);
                
               
            }
            
            if (wrapper.SalesContractUpdate_item_list.isEmpty()) {
                System.debug('No valid update items after filtering for Contract: ' + con.Id);
                continue;
            }
            
            // Serialize to JSON
            String jsonBody = JSON.serialize(wrapper.toJsonMap());
            System.debug('Full Update Payload: ' + JSON.serializePretty(jsonBody));
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:SAP_Named_Credential/' + endpoint); 
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(jsonBody);
            req.setTimeout(120000);
            
            HttpResponse res = http.send(req);
            
            List<SAPResponseWrapper> wrappers = new List<SAPResponseWrapper>();
            String status = (res.getStatusCode() == 200 || res.getStatusCode() == 201) ? 'SUCCESS' : 'ERROR';
            Integer statusCode = res.getStatusCode();
            String errorMessage = (res.getStatusCode() == 200 || res.getStatusCode() == 201) ? '' : res.getBody();
            
            System.debug('Update Status: ' + status);
            System.debug('Update Status Code: ' + statusCode);
            System.debug('Update Error Message: ' + errorMessage);
            
            
            
            wrappers.add(new SAPResponseWrapper(status, errorMessage, statusCode, res.getBody(), con.Id));
            apiLogs.add(SalesContractTriggerHelper.createApiLog(
                wrappers, jsonBody, status, errorMessage, 'POST', 'Contract Update', statusCode, con.Id
            ));
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        if (!contractsToUpdate.isEmpty()) {
            System.debug('Updating Contracts in Finish (Update Batch)');
            update contractsToUpdate;
        }
        if (!apiLogs.isEmpty()) {
            System.debug('Inserting API Logs in Finish (Update Batch)');
            insert apiLogs;
        }
    }
}