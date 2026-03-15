public class AccountInsertOutboundCalloutToSAP implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    private Set<Id> accountIds;
    private List<Account> accountsToUpdate;
    private List<API_LOG__c> apiLogs;
    
    public AccountInsertOutboundCalloutToSAP(Set<Id> accountIds) {
        this.accountIds = accountIds;
        this.accountsToUpdate = new List<Account>();
        this.apiLogs = new List<API_LOG__c>();
    }
    
    //Reconciliation_Account__c,Shipping_Condition__c,Region__c,Inco_Version__c ..Region__c,
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('This is Start Method');
        return Database.getQueryLocator([
            SELECT Id, Customer_Title__c, Name, Name_2__c, Search_Term_1__c, Search_Term_2__c, PAN__c, GST_No__c,
            Phone, Fax, Company_Email_ID__c, BillingStreet, BillingCity, BillingPostalCode, BillingState,
            BillingCountry, IFSC__c, Bank_Acc_no__c, Bank_Detail_Id__c, Bank_Country__c,Inco_Version__c,Region__c,
            Bank_Account_Holder_Name__c, Account_Group__c, Organization_Code__c, Distribution_Channel__c,Account_Assignment_Group__c,
            Division__c,  Inco_Terms__c, Payment_Terms__c,Reconciliation_Account__c,Shipping_Condition__c,Ship_To_GST_No__c,
            CurrencyIsoCode, Company_Code__c,
            Language__c, IncoTerms_Location__c, SAP_Customer_Code__c
            FROM Account
            WHERE Id IN :accountIds
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<Account> scope) {
        
        List<SAPResponseWrapper> tokenWrappers = new List<SAPResponseWrapper>();
        
        Lloyds_SFDC_Config__mdt settings = Lloyds_SFDC_Config__mdt.getInstance('Default_Config');
        String endpoint = settings.Account_Endpoint_Insert__c;

        
        Http http = new Http();
        
        for (Account acc : scope) {
            // Create and populate SAPCustomerWrapper
            SAPCustomerWrapper wrapper = new SAPCustomerWrapper();
            // Do not populate Customer_Code for inserts
            wrapper.Customer_Title = acc.Customer_Title__c != null ? acc.Customer_Title__c : '';
            wrapper.Name = acc.Name != null ? acc.Name : '';
            wrapper.Name_2 = acc.Name_2__c != null ? acc.Name_2__c : '';
            wrapper.Search_Term1 = acc.Search_Term_1__c != null ? acc.Search_Term_1__c : '';
            wrapper.Search_Term_2 = acc.Search_Term_2__c != null ? acc.Search_Term_2__c : '';
            wrapper.PAN_Number = acc.PAN__c != null ? acc.PAN__c : '';
            wrapper.GST_Number = acc.GST_No__c != null ? acc.GST_No__c : '';
            wrapper.ShipTo_GST_Number = acc.Ship_To_GST_No__c != null ? acc.Ship_To_GST_No__c :'';
            wrapper.Telephone = acc.Phone != null ? acc.Phone : '';
            wrapper.FAX_NO = acc.Fax != null ? acc.Fax : '';
            wrapper.E_Mail = acc.Company_Email_ID__c != null ? acc.Company_Email_ID__c : '';
            wrapper.Street = acc.BillingStreet != null ? acc.BillingStreet : '';
            wrapper.City = acc.BillingCity != null ? acc.BillingCity : '';
            wrapper.Postal_Code = acc.BillingPostalCode != null ? acc.BillingPostalCode : '';
            wrapper.State = '';//no need to pass because region code is enough
            
            
            //Passing keys to SAP for Country
            System.debug('Billing Country '+acc.BillingCountry);
            System.debug('Bank Country '+acc.BillingCountry);
            wrapper.Country      = AccountTriggerHelper.getCountryCode(acc.BillingCountry);
            wrapper.Bank_Country = AccountTriggerHelper.getCountryCode(acc.Bank_Country__c);
            
            //Passing keys to SAP for Region
            
            wrapper.Region = AccountTriggerHelper.getRegionCode(acc.BillingState);
            
            wrapper.Bank_Key = acc.IFSC__c != null ? acc.IFSC__c : '';
            wrapper.Bank_Account_Number = acc.Bank_Acc_no__c != null ? acc.Bank_Acc_no__c : '';
            wrapper.Bank_Detail_ID = acc.Bank_Detail_Id__c != null ? acc.Bank_Detail_Id__c : '';
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
            
            wrapper.Account_Assignment_Group = acc.Account_Assignment_Group__c != null ? acc.Account_Assignment_Group__c : '';
            wrapper.Shipping_Conditions = acc.Shipping_Condition__c != null ? acc.Shipping_Condition__c : '';
            wrapper.Reconciliation_Account = acc.Reconciliation_Account__c != null ? acc.Reconciliation_Account__c : '';
            wrapper.Incoterms = acc.Inco_Terms__c != null ? acc.Inco_Terms__c : '';
            wrapper.Inco_Version = acc.Inco_Version__c != null ? acc.Inco_Version__c : '';
            wrapper.Payment_Terms = acc.Payment_Terms__c != null ? acc.Payment_Terms__c : '';
            
            wrapper.Currency_Code = acc.CurrencyIsoCode != null ? acc.CurrencyIsoCode : '';
            
            wrapper.Company_Code = acc.Company_Code__c != null ? acc.Company_Code__c : '';
            wrapper.Language = 'EN';
            wrapper.Address_Number = '';
            wrapper.Incoterms_Location = acc.IncoTerms_Location__c != null ? acc.IncoTerms_Location__c : '';
            
            // Serialize wrapper to JSON using toJsonMap (excludes "Customer" since Customer_Code is null)
            String jsonBody = JSON.serialize(wrapper.toJsonMap());
            System.debug('Full Insert Payload: ' + jsonBody);
            
            
            
            HttpRequest req = new HttpRequest();
            //Named Credential
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
            
            System.debug('Insert Status: ' + status);
            System.debug('Insert Status Code: ' + statusCode);
            System.debug('Insert Error Message: ' + errorMessage);
            
            
            
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                
                Map<String, Object> responseMap =
                    (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                System.debug('Insert Response: ' + responseMap);
                
                String customerCode =
                    (String) AccountTriggerHelper.findKey(responseMap, 'Customer');
                
                String addressNumber =
                    (String) AccountTriggerHelper.findKey(responseMap, 'Address_Number');
                
                if (customerCode != null) {
                    Account accToUpdate = new Account(
                        Id = acc.Id,
                        SAP_Customer_Code__c = customerCode,
                        SAP_Billing_Address_Id__c = addressNumber
                    );
                    
                    accountsToUpdate.add(accToUpdate);
                    
                    System.debug('Insert Account Id: ' + acc.Id);
                    System.debug('Insert SAP_Customer_Code__c: ' + customerCode);
                    System.debug('Insert SAP_Billing_Address_Id__c: ' + addressNumber);
                } else {
                    System.debug('Customer code not found in SAP response: ' + res.getBody());
                }
            }
            
            wrappers.add(new SAPResponseWrapper(status, errorMessage, res.getStatusCode(), res.getBody(), acc.Id));
            API_Log__c logRec =
                AccountTriggerHelper.createApiLog(
                    wrappers,
                    jsonBody,
                    status,
                    errorMessage,
                    'POST',
                    'Account Insert',
                    res.getStatusCode(),
                    acc.Id
                );
            
            System.debug('LOG REC CREATED = ' + logRec);
            
            if (logRec != null) {
                apiLogs.add(logRec);
            } else {
                System.debug('LOG REC IS NULL');
            }
            System.debug('API LOGS SIZE AFTER LOOP = ' + apiLogs.size());
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        if (!accountsToUpdate.isEmpty()) {
            System.debug('Updating Accounts in Finish');
            update accountsToUpdate;
        }
        
        if (!apiLogs.isEmpty()) {
            try {
                System.debug('FINISH STARTED');
                System.debug('API LOGS SIZE IN FINISH = ' + apiLogs.size());
                insert apiLogs;
            } catch (DmlException e) {
                System.debug('API LOG INSERT FAILED: ' + e.getMessage());
                System.debug('API LOG RECORDS: ' + apiLogs);
            }
        }
    }
}