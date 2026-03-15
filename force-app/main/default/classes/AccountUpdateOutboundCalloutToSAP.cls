public class AccountUpdateOutboundCalloutToSAP implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    private Set<Id> accountIds;
    private List<API_LOG__c> apiLogs;
    private List<Account> accountsToUpdate = new List<Account>();
    private List<Address__c> shippingAddressesToUpdate = new List<Address__c>();
    
    public AccountUpdateOutboundCalloutToSAP(Set<Id> accountIds) {
        this.accountIds = accountIds;
        this.apiLogs = new List<API_LOG__c>();
    }
    
    //Reconciliation_Account__c,Shipping_Condition__c,Inco_Version__c,Region__c..Region__c,
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('This is Start Method for Update');
        return Database.getQueryLocator([
            SELECT Id, Customer_Title__c, Name, Name_2__c, Search_Term_1__c, Search_Term_2__c, PAN__c, GST_No__c,
            Phone, Fax, Company_Email_ID__c, BillingStreet, BillingCity, BillingPostalCode, BillingState,
            BillingCountry, IFSC__c, Bank_Acc_no__c, Bank_Detail_Id__c, Bank_Country__c,
            Bank_Account_Holder_Name__c, Account_Group__c, Organization_Code__c, Distribution_Channel__c,Region__c,
            Division__c,  Inco_Terms__c, Payment_Terms__c,Reconciliation_Account__c,Shipping_Condition__c,Inco_Version__c,
            Account_Assignment_Group__c, CurrencyIsoCode,  Company_Code__c,SAP_Billing_Address_Id__c,
            Language__c, IncoTerms_Location__c, SAP_Customer_Code__c,Shipping_Address__c,Is_Shipping_Update__c
            FROM Account
            WHERE Id IN :accountIds
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<Account> scope) {      
        
        
        List<SAPResponseWrapper> tokenWrappers = new List<SAPResponseWrapper>();
        
        //Querying the Address__c Ids from Account Lookup
        Set<Id> shippingAddrIds = new Set<Id>();
        for (Account acc : scope) {
            if (acc.Shipping_Address__c != null) {
                shippingAddrIds.add(acc.Shipping_Address__c);
            }
        }
        
        //Querying Address_c records
        Map<Id, Address__c> shippingAddrMap = new Map<Id, Address__c>();
        
        if (!shippingAddrIds.isEmpty()) {
            shippingAddrMap = new Map<Id, Address__c>([
                SELECT Id,
                Address_Type__c,
                SAP_Shipping_Address_Id__c,
                Shipping_Address__Street__s,
                Shipping_Address__City__s,
                Shipping_Address__StateCode__s,
                Shipping_Address__PostalCode__s,
                Shipping_Address__CountryCode__s
                FROM Address__c
                WHERE Id IN :shippingAddrIds
            ]);
        }
        
        Lloyds_SFDC_Config__mdt settings = Lloyds_SFDC_Config__mdt.getInstance('Default_Config');
        String endpoint = settings.Account_Endpoint_Update__c;

        
        Http http = new Http();
        
        for (Account acc : scope) {
            
            Boolean isShippingUpdate = acc.Is_Shipping_Update__c == true;
            
            // Validate SAP_Customer_Code__c is not null
            if (acc.SAP_Customer_Code__c == null) {
                tokenWrappers.add(new SAPResponseWrapper('ERROR', 'SAP Customer Code is missing', 400, null, acc.Id));
                apiLogs.add(AccountTriggerHelper.createApiLog(tokenWrappers, null, 'Failure', 'SAP Customer Code is missing', 'PATCH', 'Update', 400, acc.Id));
                continue;
            }
            
            // Create and populate SAPCustomerWrapper
            SAPCustomerWrapper wrapper = new SAPCustomerWrapper();
            wrapper.Customer_Code = acc.SAP_Customer_Code__c; // Include SAP_Customer_Code__c for updates
            wrapper.Customer_Title = acc.Customer_Title__c != null ? acc.Customer_Title__c : '';
            wrapper.Name = acc.Name != null ? acc.Name : '';
            wrapper.Name_2 = acc.Name_2__c != null ? acc.Name_2__c : '';
            wrapper.Search_Term1 = acc.Search_Term_1__c != null ? acc.Search_Term_1__c : '';
            wrapper.Search_Term_2 = acc.Search_Term_2__c != null ? acc.Search_Term_2__c : '';
            wrapper.PAN_Number = acc.PAN__c != null ? acc.PAN__c : '';
            wrapper.GST_Number = acc.GST_No__c != null ? acc.GST_No__c : '';
            wrapper.Telephone = acc.Phone != null ? acc.Phone : '';
            wrapper.FAX_NO = acc.Fax != null ? acc.Fax : '';
            wrapper.E_Mail = acc.Company_Email_ID__c != null ? acc.Company_Email_ID__c : '';
            
            if (isShippingUpdate && !shippingAddrMap.containsKey(acc.Shipping_Address__c)) {
                // Address record missing – skip safely
                continue;
            }
            
            //Choosing whether Sending Billing Address or Shipping Address
            if (isShippingUpdate) {
                // SHIPPING ADDRESS
                Address__c shipAddr = shippingAddrMap.get(acc.Shipping_Address__c);
                
                wrapper.Street = shipAddr.Shipping_Address__Street__s;
                wrapper.City = shipAddr.Shipping_Address__City__s;
                wrapper.State = '';
                wrapper.Postal_Code = shipAddr.Shipping_Address__PostalCode__s;
                 System.debug(':::Shipping State:::'+shipAddr.Shipping_Address__StateCode__s);
                
                wrapper.Region = AccountTriggerHelper.getRegionCode(
                    shipAddr.Shipping_Address__StateCode__s
                );
                wrapper.Country = shipAddr.Shipping_Address__CountryCode__s;
                
                wrapper.Address_Number =
                    shipAddr.SAP_Shipping_Address_Id__c != null
                    ? shipAddr.SAP_Shipping_Address_Id__c
                    : '';
            } else {
                // BILLING ADDRESS
                wrapper.Street = acc.BillingStreet;
                wrapper.State = '';
                wrapper.City = acc.BillingCity;
                wrapper.Postal_Code = acc.BillingPostalCode;
                 System.debug(':::Billing State:::'+acc.BillingState);
                wrapper.Region = AccountTriggerHelper.getRegionCode(acc.BillingState);
                wrapper.Country = AccountTriggerHelper.getCountryCode(acc.BillingCountry);
                
                wrapper.Address_Number = acc.SAP_Billing_Address_Id__c;
            }
            
            wrapper.Bank_Country = AccountTriggerHelper.getCountryCode(acc.Bank_Country__c);
            
            
            
            wrapper.Bank_Key = acc.IFSC__c != null ? acc.IFSC__c : '';
            wrapper.Bank_Account_Number = acc.Bank_Acc_no__c != null ? acc.Bank_Acc_no__c : '';
            wrapper.Bank_Detail_ID = '0001';//acc.Bank_Detail_Id__c != null ? acc.Bank_Detail_Id__c : '';
            
            wrapper.Account_Holder_Name = acc.Bank_Account_Holder_Name__c != null ? acc.Bank_Account_Holder_Name__c : '';
            wrapper.Customer_Account_Group = acc.Account_Group__c != null ? acc.Account_Group__c : '';
            wrapper.Sales_Organization = acc.Organization_Code__c != null ? acc.Organization_Code__c : '';
            wrapper.Distribution_Channel = acc.Distribution_Channel__c != null 
                ? (acc.Distribution_Channel__c.length() == 1 ? '0' + acc.Distribution_Channel__c : acc.Distribution_Channel__c)
                : '';
            
            /*wrapper.Division = acc.Division__c != null 
                ? (acc.Division__c.length() == 1 ? '0' + acc.Division__c : acc.Division__c)
                : '';*/
            wrapper.Division = '00';
            wrapper.Shipping_Conditions = acc.Shipping_Condition__c != null ? acc.Shipping_Condition__c : '';
            wrapper.Incoterms = acc.Inco_Terms__c != null ? acc.Inco_Terms__c : '';
            wrapper.Inco_Version = acc.Inco_Version__c != null ? acc.Inco_Version__c : '';
            wrapper.Payment_Terms = acc.Payment_Terms__c != null ? acc.Payment_Terms__c : '';
            wrapper.Account_Assignment_Group = acc.Account_Assignment_Group__c != null ? acc.Account_Assignment_Group__c : '';
            wrapper.Currency_Code = acc.CurrencyIsoCode != null ? acc.CurrencyIsoCode : '';
            wrapper.Reconciliation_Account = acc.Reconciliation_Account__c != null ? acc.Reconciliation_Account__c : '';
            wrapper.Company_Code = acc.Company_Code__c != null ? acc.Company_Code__c : '';
            wrapper.Language = 'EN';
            wrapper.Incoterms_Location = acc.IncoTerms_Location__c != null ? acc.IncoTerms_Location__c : '';
            
            // Serialize wrapper to JSON using toJsonMap to include "Customer" and "Currency" keys
            String jsonBody = JSON.serialize(wrapper.toJsonMap());
            System.debug('Full Update Payload: ' + JSON.serializePretty(jsonBody));
            
            
            HttpRequest req = new HttpRequest();
            ////Named Credential
			req.setEndpoint('callout:SAP_Named_Credential/'+endpoint);            
            req.setMethod('POST');	
            req.setHeader('Content-Type', 'application/json');
            req.setBody(jsonBody);
            req.setTimeout(120000);
            
            HttpResponse res = http.send(req);
            List<SAPResponseWrapper> wrappers = new List<SAPResponseWrapper>();
            String status = (res.getStatusCode() == 200 || res.getStatusCode() == 201) ? 'Success' : 'Failure';
            Integer statusCode = res.getStatusCode();
            String errorMessage = (res.getStatusCode() == 200 || res.getStatusCode() == 201) ? '' : res.getBody();
            
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                // Store SAP Shipping Address Number
                if (isShippingUpdate
                    && acc.Shipping_Address__c != null
                    && responseMap.containsKey('Address_Number')) {
                        
                        shippingAddressesToUpdate.add(new Address__c(
                            Id = acc.Shipping_Address__c,
                            SAP_Shipping_Address_Id__c =
                            (String) responseMap.get('Address_Number')
                        ));
                    }
            }
            
            System.debug('Update Status: ' + status);
            System.debug('Update Status Code: ' + statusCode);
            System.debug('Update Error Message: ' + errorMessage);
            
            if (status == 'Success') {
                accountsToUpdate.add(new Account(
                    Id = acc.Id,
                    Needs_Sensitive_Field_Check__c = false,
                    Is_Shipping_Update__c = false
                ));
            }
            
            // Log the API call without updating the Account
            wrappers.add(new SAPResponseWrapper(status, errorMessage, res.getStatusCode(), res.getBody(), acc.Id));
            apiLogs.add(AccountTriggerHelper.createApiLog(wrappers, jsonBody, status, errorMessage, 'PATCH', 'Account Update', res.getStatusCode(), acc.Id));
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        if (!apiLogs.isEmpty()) {
            System.debug('Inserting API Logs in Finish');
            insert apiLogs;
            
        }
        if (!shippingAddressesToUpdate.isEmpty()) {
            update shippingAddressesToUpdate;
        }
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }
    
}