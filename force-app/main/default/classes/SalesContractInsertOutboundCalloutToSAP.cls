public class SalesContractInsertOutboundCalloutToSAP implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    private Set<Id> contractIds;
    private List<Contract> contractsToUpdate;
    private List<API_LOG__c> apiLogs;
    private List<Contract> failedContracts = new List<Contract>();
    private List<Sales_Contract_Line_Item__c> lineItemsToUpdate = new List<Sales_Contract_Line_Item__c>();
    
    public SalesContractInsertOutboundCalloutToSAP(Set<Id> contractIds) {
        this.contractIds = contractIds;
        this.contractsToUpdate = new List<Contract>();
        this.apiLogs = new List<API_LOG__c>();
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('Starting Contract Insert Batch');
        return Database.getQueryLocator([
            SELECT Id, Contract_TypeNew__c, Ship_to_Party__c, Sold_to_Party__c, Sales_Organization_N__c,
            Distribution_Channel_N__c, Division_N__c, Customer_Reference__c, Cust_Ref_Date__c,
            Valid_From__c, Valid_To__c, Pricing_Date__c, Text_Header__c, Text_0025__c, Text_0024__c, Text_Z130__c,
            Text_Z245__c, Text_Z247__c, Incoterms__c,Incolocation__c,Payment_Terms__c,Quotation_Number__c,Shipping_Address__r.SAP_Shipping_Address_Id__c
            FROM Contract
            WHERE Id IN :contractIds
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<Contract> scope) {
        
        List<SAPResponseWrapper> tokenWrappers = new List<SAPResponseWrapper>();
        
        Lloyds_SFDC_Config__mdt settings = Lloyds_SFDC_Config__mdt.getInstance('Default_Config');
        String endpoint = settings.Sales_Contract_Endpoint_Insert__c;
        Http http = new Http();
        
        // Query Contract Line Items
        Map<Id, List<Sales_Contract_Line_Item__c>> contractLineItemsMap = new Map<Id, List<Sales_Contract_Line_Item__c>>();
        for (Sales_Contract_Line_Item__c cli : [
            SELECT Id, Contract__c, Product_Code__c, Contract_Document_Item_Number__c, Target_Quantity__c,
            Unit_Of_Measure__c, CurrencyIsoCode, Plant__c, Profit_Center__c, Text_Item__c,
            Pricing_Conditions__c, Condition_Pricing_Unit__c, Condition_Unit_of_Measure__c,
            Partner_Function__c, Customer_Number__c,Text_Z001__c,Text_Z003__c,Text_Z004__c,Text_Z006__c,
            Text_Z009__c,Text_Z013__c,Text_Z014__c,Text_Z015__c,Text_Z016__c,Text_Z017__c,Text_Z220__c,Quantity__c
            FROM Sales_Contract_Line_Item__c
            WHERE Contract__c IN :scope
        ]) {
            if (!contractLineItemsMap.containsKey(cli.Contract__c)) {
                contractLineItemsMap.put(cli.Contract__c, new List<Sales_Contract_Line_Item__c>());
            }
            contractLineItemsMap.get(cli.Contract__c).add(cli);
        }
        
        for (Contract con : scope) {
            Set<Id> processedLineItems = new Set<Id>();
            
            String sapShippingAddressId = '';
            
            if (con.Shipping_Address__r != null) {
                sapShippingAddressId = con.Shipping_Address__r.SAP_Shipping_Address_Id__c;
            }
            
            SAPContractWrapper wrapper = new SAPContractWrapper();
            wrapper.Contract_Type = con.Contract_TypeNew__c != null ? con.Contract_TypeNew__c : '';
            wrapper.SH_address_No = sapShippingAddressId;
            wrapper.Ship_to_Party = con.Ship_to_Party__c != null ? con.Ship_to_Party__c : '';
            wrapper.Sold_to_Party = con.Sold_to_Party__c != null ? con.Sold_to_Party__c : '';
            wrapper.Sales_Organization = con.Sales_Organization_N__c != null ? con.Sales_Organization_N__c : '';
            
            wrapper.Distribution_Channel = con.Distribution_Channel_N__c != null ? 
                (con.Distribution_Channel_N__c.length()== 1 ? '0'+con.Distribution_Channel_N__c : con.Distribution_Channel_N__c):'';
            wrapper.Division = con.Division_N__c != null ? 
                (con.Division_N__c.length()== 1 ? '0'+con.Division_N__c : con.Division_N__c):'';         
            
            wrapper.Customer_Reference = con.Customer_Reference__c != null ? con.Customer_Reference__c : '';
            wrapper.Cust_Ref_Date = SAPContractWrapper.formatDate(con.Cust_Ref_Date__c);
            wrapper.Valid_From = SAPContractWrapper.formatDate(con.Valid_From__c);
            wrapper.Valid_To = SAPContractWrapper.formatDate(con.Valid_To__c);
            wrapper.Pricing_Date = SAPContractWrapper.formatDate(con.Pricing_Date__c);
            wrapper.Incolocation = con.Incolocation__c != null ? con.Incolocation__c  : '';
            wrapper.Incoterms = con.Incoterms__c != null ? con.Incoterms__c  : '';
            wrapper.Payment_Terms = con.Payment_Terms__c != null ? con.Payment_Terms__c  : '';
            wrapper.Quotation_Number = con.Quotation_Number__c != null ? con.Quotation_Number__c  : '';
            wrapper.Salesforce_Contract_Id = con.Id != null ? con.Id  : '';
            
            // Handle Header_Texts (Multi-Select Picklist)
            wrapper.Header_Texts = SalesContractTriggerHelper.buildHeaderTexts(con);
            
            // Handle Contract Line Items
            if (contractLineItemsMap.containsKey(con.Id)) {
                Integer itemCounter = 10;
                wrapper.Contract_item_list = new List<SAPContractWrapper.ContractItem>();
                for (Sales_Contract_Line_Item__c cli : contractLineItemsMap.get(con.Id)) {
                    
                    SAPContractWrapper.ContractItem item = new SAPContractWrapper.ContractItem();
                    //why we need to?
                    item.Contract_Document_Item_Number = String.valueOf(itemCounter);
                    item.Product_Number = cli.Product_Code__c != null ? cli.Product_Code__c : '';
                    item.Target_quantity = cli.Quantity__c != null ? String.valueOf(cli.Quantity__c) : '';
                    item.Unit_of_Measure = cli.Unit_Of_Measure__c != null ? cli.Unit_Of_Measure__c : '';
                    item.Currency_Code = cli.CurrencyIsoCode != null ? String.valueOf(cli.CurrencyIsoCode) : '';
                    item.Plant = cli.Plant__c != null ? cli.Plant__c : '';
                    
                    item.Profit_Center = '';
                    item.Condition_Pricing_Unit = '';
                    item.Condition_Unit_of_Measure = '';
                    item.Partner_Function = '';
                    item.Customer_Number = '';
                    
                    // Handle Lineitem_Texts (Multi-Select Picklist)
                    item.Lineitem_Texts = SalesContractLineItemHelper.buildLineItemTexts(cli);
                    
                    
                    // Handle Pricing_Conditions (JSON in Text Area)
                    if (cli.Pricing_Conditions__c != null) {
                        item.Pricing_Conditions = new List<SAPContractWrapper.PricingCondition>();
                        try {
                            String cleanJson = cli.Pricing_Conditions__c;
                            cleanJson = cleanJson.replaceAll('[\\x00-\\x1F]', '').trim();
                            
                            System.debug('Sanitized Pricing_Conditions JSON: ' + cleanJson);
                            
                            Map<String, Object> pricingJson = (Map<String, Object>) JSON.deserializeUntyped(cleanJson);
                            List<Object> conditions = (List<Object>) pricingJson.get('Pricing_Conditions');
                            
                            for (Object cond : conditions) {
                                Map<String, Object> condMap = (Map<String, Object>) cond;
                                SAPContractWrapper.PricingCondition pc = new SAPContractWrapper.PricingCondition();
                                pc.Condition_type = (String) condMap.get('Condition_type');
                                pc.Amount = String.valueOf(condMap.get('Amount'));
                                pc.Condition_Unit = (String) condMap.get('Condition_Unit');
                                item.Pricing_Conditions.add(pc);
                            }
                        } catch (Exception e) {
                            System.debug('Error parsing Pricing_Conditions__c for Contract Line Item ' + cli.Id + ': ' + e.getMessage());
                            apiLogs.add(AccountTriggerHelper.createApiLog(
                                new List<SAPResponseWrapper>{
                                    new SAPResponseWrapper('ERROR', 'Invalid Pricing_Conditions JSON: ' + e.getMessage(), 400, null, con.Id)
                                        },
                                cli.Pricing_Conditions__c, 'Failure', 'Invalid Pricing_Conditions JSON',
                                'POST', 'Contract Insert', 400, con.Id
                            ));
                        }
                    }
                    
                    wrapper.Contract_item_list.add(item);
                    itemCounter += 10;
                }
            }
            
            // Serialize wrapper to JSON
            String jsonBody = JSON.serialize(wrapper.toJsonMap());
            System.debug(wrapper.toOrderedJsonPretty());
            
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
            
            System.debug('Insert Status: ' + status);
            System.debug('Insert Status Code: ' + statusCode);
            System.debug('Insert Error Message: ' + errorMessage);
            
            // --- Added Safe Handling for Non-JSON Response ---
            System.debug('Raw SAP Insert Response Body ===> ' + res.getBody());
            String responseBody = res.getBody().replaceAll('[\\x00-\\x1F]', '');
            
            
            Map<String, Object> rootResponse;
            String contractNumber = null;
            Map<String, String> productToItemNo = new Map<String, String>();
            
            try {
                rootResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                
                // STEP 1: Validate new SAP wrapper
                if (!rootResponse.containsKey('SFDC_SalesContract_Res')) {
                    apiLogs.add(
                        SalesContractTriggerHelper.createApiLog(
                            new List<SAPResponseWrapper>{
                                new SAPResponseWrapper(
                                    'ERROR',
                                    'Missing SFDC_SalesContract_Res',
                                    statusCode,
                                    responseBody,
                                    con.Id
                                )
                                    },
                            responseBody,
                            'Failure',
                            'Invalid SAP response structure',
                            'POST',
                            'Contract Insert',
                            statusCode,
                            con.Id
                        )
                    );
                    continue;
                }
                
                // STEP 2: Navigate to SalesContract_Res
                Map<String, Object> sfdcWrapper =
                    (Map<String, Object>) rootResponse.get('SFDC_SalesContract_Res');
                
                if (!sfdcWrapper.containsKey('SalesContract_Res')) {
                    continue;
                }
                
                List<Object> resList =
                    (List<Object>) sfdcWrapper.get('SalesContract_Res');
                
                // STEP 3: Read contract number + line items
                for (Object obj : resList) {
                    Map<String, Object> record = (Map<String, Object>) obj;
                    
                    // Contract number (same for all records)
                    if (contractNumber == null) {
                        contractNumber = (String) record.get('Contact_Number');
                    }
                    
                    Object lineItemObj = record.get('Line_item');
                    List<Object> lineItems = new List<Object>();
                    
                    // Normalize Line_item (Object OR List)
                    if (lineItemObj instanceof Map<String, Object>) {
                        lineItems.add(lineItemObj);
                    } else if (lineItemObj instanceof List<Object>) {
                        lineItems.addAll((List<Object>) lineItemObj);
                    }
                    
                    // Map Product → SAP Item Number
                    for (Object li : lineItems) {
                        Map<String, Object> liMap = (Map<String, Object>) li;
                        
                        String product = SalesContractTriggerHelper.normalizeProductCode((String) liMap.get('Product_Number'));
                        
                        String itemNo =
                            SalesContractTriggerHelper.normalizeProductCode((String) liMap.get('Line_Item_Number'));
                        
                        if (!String.isBlank(product) && !String.isBlank(itemNo)) {
                            productToItemNo.put(product, itemNo);
                        }
                    }
                }
                
                // STEP 4: Update Contract with SAP number
                if (contractNumber != null) {
                    contractsToUpdate.add(new Contract(
                        Id = con.Id,
                        SAP_Sales_Contract_Number__c = contractNumber
                    ));
                }
                
                // STEP 5: Update Line Items correctly
                List<Sales_Contract_Line_Item__c> cliUpdates =
                    new List<Sales_Contract_Line_Item__c>();
                
                if (contractLineItemsMap.containsKey(con.Id)) {
                    for (Sales_Contract_Line_Item__c cli : contractLineItemsMap.get(con.Id)) {
                        
                        String sfProduct = SalesContractTriggerHelper.normalizeProductCode(cli.Product_Code__c);
                        
                        if (productToItemNo.containsKey(sfProduct)
                            && !processedLineItems.contains(cli.Id)) {
                                
                                cliUpdates.add(new Sales_Contract_Line_Item__c(
                                    Id = cli.Id,
                                    Contract_Document_Item_Number__c =
                                    productToItemNo.get(sfProduct)
                                ));
                                
                                processedLineItems.add(cli.Id);
                            }
                    }
                }
                
                lineItemsToUpdate.addAll(cliUpdates);
                
                // STEP 6: Success log
                wrappers.add(new SAPResponseWrapper(
                    status, errorMessage, res.getStatusCode(), res.getBody(), con.Id
                ));
                
                apiLogs.add(
                    SalesContractTriggerHelper.createApiLog(
                        wrappers, jsonBody, status, errorMessage,
                        'POST', 'Contract Insert', res.getStatusCode(), con.Id
                    )
                );
                
            } catch (Exception e) {
                apiLogs.add(
                    SalesContractTriggerHelper.createApiLog(
                        new List<SAPResponseWrapper>{
                            new SAPResponseWrapper(
                                'ERROR',
                                e.getMessage(),
                                statusCode,
                                responseBody,
                                con.Id
                            )
                                },
                        responseBody,
                        'Failure',
                        'SAP response parsing failed',
                        'POST',
                        'Contract Insert',
                        statusCode,
                        con.Id
                    )
                );
            }
            
            // --- UNIVERSAL CHECK: If still no SAP number → allow retry
            if (contractNumber == null) {
                failedContracts.add(
                    new Contract(
                        Id = con.Id,
                        Trigger_SAP_Insert__c = false
                    )
                );
            }
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        
        if (!contractsToUpdate.isEmpty()) {
            System.debug('Updating Contracts in Finish');
            update contractsToUpdate;
        }
        
        if (!lineItemsToUpdate.isEmpty()) {
            update lineItemsToUpdate;
        }
        

        if (!apiLogs.isEmpty()) {
            System.debug('Inserting API Logs in Finish');
            insert apiLogs;
        }
        if (!failedContracts.isEmpty()) {
            System.debug('Updating Trigger to SAP Insert to False');
            update failedContracts; 
        }
    }
}