public class AccountTriggerHelper {
    
    // Marks the flag TRUE when sensitive fields are edited
    public static void markSensitiveFlag(List<Account> newList, Map<Id, Account> oldMap) {
        for (Account acc : newList) {
            Account oldAcc = oldMap.get(acc.Id);
            if (oldAcc == null) continue;
            
            Boolean sensitiveChanged =
                acc.PAN__c != oldAcc.PAN__c ||
                acc.GST_No__c != oldAcc.GST_No__c ||
                acc.IFSC__c != oldAcc.IFSC__c ||
                acc.Bank_Acc_no__c != oldAcc.Bank_Acc_no__c ||
                acc.Bank_Account_Holder_Name__c != oldAcc.Bank_Account_Holder_Name__c;
            
            if (sensitiveChanged) {
                System.debug('Sensitive Field-true');
                acc.Needs_Sensitive_Field_Check__c = true;
            }
        }
    }
    
    public static void prepareUpdateFlags(
        List<Account> newList,
        Map<Id, Account> oldMap
    ) {
        for (Account acc : newList) {
            Account oldAcc = oldMap.get(acc.Id);
            if (oldAcc == null) continue;
            
            Boolean billingAddressChanged =
                acc.BillingStreet != oldAcc.BillingStreet ||
                acc.BillingCity != oldAcc.BillingCity ||
                acc.BillingPostalCode != oldAcc.BillingPostalCode ||
                acc.BillingState != oldAcc.BillingState ||
                acc.BillingCountry != oldAcc.BillingCountry;
            
            Boolean shippingLookupChanged =
                acc.Shipping_Address__c != oldAcc.Shipping_Address__c;
            
            // Block both changes together
            if (billingAddressChanged && shippingLookupChanged) {
                acc.addError(
                    'You cannot update Billing Address and Shipping Address at the same time.'
                );
                continue;
            }
            
            // Set intent flag
            if (shippingLookupChanged) {
                acc.Is_Shipping_Update__c = true;
            } else if (billingAddressChanged) {
                acc.Is_Shipping_Update__c = false;
            }
        }
    }
    
    // New wrapper method for SAP sync logic
    public static void processSAPSync(List<Account> newList, Map<Id, Account> oldMap) {
        Set<Id> insertIds = fetchSAPInsertIds(newList, oldMap);
        Set<Id> updateIds = fetchSAPUpdateIds(newList, oldMap);
        
        if (!insertIds.isEmpty()) {
            Database.executeBatch(new AccountInsertOutboundCalloutToSAP(insertIds), 50);
        }
        if (!updateIds.isEmpty()) {
            Database.executeBatch(new AccountUpdateOutboundCalloutToSAP(updateIds), 50);
        }
    }
    
    
    public static Set<Id> fetchSAPInsertIds(List<Account> accountList, Map<Id, Account> oldMap) {
        Set<Id> accInsertIds = new Set<Id>();
        for (Account acc : accountList) {
            Account oldAcc = oldMap.get(acc.Id);
            if(acc.SAP_Customer_Code__c == null && 
               acc.Account_Approval_Status__c == 'Approved' && 
               oldAcc.Account_Approval_Status__c == 'Approval') 
            {
                accInsertIds.add(acc.Id);
            }
        }
        return accInsertIds;
    }
    
    public static Set<Id> fetchSAPUpdateIds(List<Account> accountList, Map<Id, Account> oldMap) {
        Set<Id> accUpdateIds = new Set<Id>();
        for (Account acc : accountList) {
            Account oldAcc = oldMap.get(acc.Id);
            
            
            // Identify if sensitive fields changed
            Boolean sensitiveChanged =
                acc.PAN__c != oldAcc.PAN__c ||
                acc.GST_No__c != oldAcc.GST_No__c ||
                acc.IFSC__c != oldAcc.IFSC__c ||
                acc.Bank_Acc_no__c != oldAcc.Bank_Acc_no__c ||
                acc.Bank_Account_Holder_Name__c != oldAcc.Bank_Account_Holder_Name__c;
            
            // Identify if normal fields changed
            Boolean normalChanged =
                acc.Customer_Title__c != oldAcc.Customer_Title__c ||
                acc.Name != oldAcc.Name ||
                acc.Name_2__c != oldAcc.Name_2__c ||
                acc.Search_Term_1__c != oldAcc.Search_Term_1__c ||
                acc.Search_Term_2__c != oldAcc.Search_Term_2__c ||
                acc.Phone != oldAcc.Phone ||
                acc.Fax != oldAcc.Fax ||
                acc.Company_Email_ID__c != oldAcc.Company_Email_ID__c ||
                acc.BillingStreet != oldAcc.BillingStreet ||
                acc.BillingCity != oldAcc.BillingCity ||
                acc.BillingPostalCode != oldAcc.BillingPostalCode ||
                acc.BillingState != oldAcc.BillingState ||
                acc.BillingCountry != oldAcc.BillingCountry ||
                acc.Region__c != oldAcc.Region__c ||
                acc.Bank_Detail_Id__c != oldAcc.Bank_Detail_Id__c ||
                acc.Bank_Country__c != oldAcc.Bank_Country__c ||
                acc.Account_Group__c != oldAcc.Account_Group__c ||
                acc.Organization_Code__c != oldAcc.Organization_Code__c ||
                acc.Distribution_Channel__c != oldAcc.Distribution_Channel__c ||
                acc.Division__c != oldAcc.Division__c ||
                acc.Shipping_Condition__c != oldAcc.Shipping_Condition__c ||
                acc.Inco_Terms__c != oldAcc.Inco_Terms__c ||
                acc.Inco_Version__c != oldAcc.Inco_Version__c ||
                acc.Payment_Terms__c != oldAcc.Payment_Terms__c ||
                acc.Account_Assignment_Group__c != oldAcc.Account_Assignment_Group__c ||
                acc.CurrencyIsoCode != oldAcc.CurrencyIsoCode ||
                acc.Reconciliation_Account__c != oldAcc.Reconciliation_Account__c ||
                acc.Company_Code__c != oldAcc.Company_Code__c ||
                acc.Language__c != oldAcc.Language__c ||
                acc.IncoTerms_Location__c != oldAcc.IncoTerms_Location__c;
            
            Boolean billingAddressChanged =
                acc.BillingStreet != oldAcc.BillingStreet ||
                acc.BillingCity != oldAcc.BillingCity ||
                acc.BillingPostalCode != oldAcc.BillingPostalCode ||
                acc.BillingState != oldAcc.BillingState ||
                acc.BillingCountry != oldAcc.BillingCountry;
            
            Boolean shouldSync = false;
            
            // Case 1: Normal fields changed while remaining Approved
            if (acc.Account_Approval_Status__c == 'Approved' &&
                oldAcc.Account_Approval_Status__c == 'Approved' &&
                (normalChanged || billingAddressChanged) &&
                !sensitiveChanged) 
            {
                
                shouldSync = true;
            }
            
            // Case 2: Sensitive fields changed earlier, and now the approval is completed
            if (acc.Account_Approval_Status__c == 'Approved' &&
                oldAcc.Account_Approval_Status__c == 'Approval' &&
                acc.Needs_Sensitive_Field_Check__c == true) 
            {
                shouldSync = true;
            }
            
            // Case 3: Shipping address lookup changed (new shipping address)
            if (acc.Account_Approval_Status__c == 'Approved'
                && oldAcc.Account_Approval_Status__c == 'Approved'
                && acc.Is_Shipping_Update__c == true
                && acc.SAP_Customer_Code__c != null) 
            {
                shouldSync = true;
            }
            
            if (acc.SAP_Customer_Code__c != null && shouldSync) {
                accUpdateIds.add(acc.Id);
            }
            
            
        }
        return accUpdateIds;
    }
    
    
    public static String getRegionCode(String inputState) {
        
        System.debug('Trigger Helper Input State => ' + inputState);
        
        if (String.isBlank(inputState)) {
            return null;
        }
        
        inputState = inputState.trim();
        
        String stateName;
        String stateCode;
        
        // Case 1: "29 - Karnataka"
        if (inputState.contains('-')) {
            List<String> parts = inputState.split('-');
            if (parts.size() > 1) {
                stateName = parts[1].trim();
            }
        }
        // Case 2: "KA", "TN", "NL"
        else if (inputState.length() == 2) {
            stateCode = inputState;
        }
        // Case 3: "Karnataka"
        else {
            stateName = inputState;
        }
        
        System.debug('Resolved StateName => ' + stateName);
        System.debug('Resolved StateCode => ' + stateCode);
        
        try {
            StateCode__mdt mapping;
            
            if (stateName != null) {
                mapping = [
                    SELECT SAP_State_Code__c
                    FROM StateCode__mdt
                    WHERE State__c = :stateName
                    LIMIT 1
                ];
            } else {
                mapping = [
                    SELECT SAP_State_Code__c
                    FROM StateCode__mdt
                    WHERE Salesforce_Code__c = :stateCode
                    LIMIT 1
                ];
            }
            
            System.debug('Resolved SAP State Code => ' + mapping.SAP_State_Code__c);
            return mapping.SAP_State_Code__c;
        }
        catch (QueryException e) {
            System.debug('No State mapping found');
            return null;
        }
    }
    
    
    
    // Reusable method for mapping country name → country code
    public static String getCountryCode(String countryName) {
        if (String.isBlank(countryName)) {
            return '';
        }
        
        Schema.DescribeFieldResult fieldResult = Account.CountryCode__c.getDescribe();
        List<Schema.PicklistEntry> pickValues = fieldResult.getPicklistValues();
        
        for (Schema.PicklistEntry entry : pickValues) {
            String val = entry.getValue(); // Ex: "IN - India"
            List<String> parts = val.split('-');
            
            if (parts.size() == 2) {
                String code = parts[0].trim();
                String name = parts[1].trim();
                
                if (name.equalsIgnoreCase(countryName.trim())) {
                    return code;
                }
            }
        }
        return '';
    }
    
    
    public static API_LOG__c createApiLog(List<SAPResponseWrapper> responseWrappers,String jsonBody,String status,String errorMessage,String method,String scope,Integer statusCode,Id recordId) {
        API_LOG__c apiLog = new API_LOG__c();
        
        System.debug('========== CREATE API LOG DEBUG START ==========');
        System.debug('Status      : ' + status);
        System.debug('Method      : ' + method);
        System.debug('Scope       : ' + scope);
        System.debug('Status Code : ' + statusCode);
        System.debug('Record Id   : ' + recordId);
        System.debug('Request len : ' + (jsonBody != null ? jsonBody.length() : 0));
        System.debug('Response len: ' + (responseWrappers != null ? JSON.serialize(responseWrappers).length() : 0));
        
        apiLog.Status__c = status;
        apiLog.Error__c = errorMessage;
        apiLog.Request__c = jsonBody;
        apiLog.Response__c = JSON.serialize(responseWrappers);
        apiLog.Method__c = method;
        apiLog.Scope__c = scope;
        apiLog.Status_Code__c = String.valueOf(statusCode);
        apiLog.Record_Id__c = recordId;
        
        System.debug('API LOG OBJECT BEFORE INSERT => ' + apiLog);
        System.debug('========== CREATE API LOG DEBUG END ==========');
        
        return apiLog;
    }
    
    
    //Find the Key to Identify the SAP Number
    public static Object findKey(Object jsonObj, String key) {
        if (jsonObj == null) return null;
        
        if (jsonObj instanceof Map<String, Object>) {
            Map<String, Object> mapObj = (Map<String, Object>) jsonObj;
            
            if (mapObj.containsKey(key)) {
                return mapObj.get(key);
            }
            
            for (Object val : mapObj.values()) {
                Object found = findKey(val, key);
                if (found != null) return found;
            }
        }
        else if (jsonObj instanceof List<Object>) {
            for (Object item : (List<Object>) jsonObj) {
                Object found = findKey(item, key);
                if (found != null) return found;
            }
        }
        return null;
    }

    
    public static void validateRejectionComments(List<Account> newList, Map<Id, Account> oldMap) {
        Map<Id, Account> rejectedAccounts = new Map<Id, Account>();
        
        for (Account acc : newList) {
            Account oldAcc = oldMap.get(acc.Id);
            
            if (
                oldAcc.Account_Approval_Status__c != null &&
                acc.Account_Approval_Status__c != null &&
                oldAcc.Account_Approval_Status__c.toLowerCase() != 'Rejected' &&
                acc.Account_Approval_Status__c.toLowerCase() == 'Rejected'
            ) {
                rejectedAccounts.put(acc.Id, acc);
            }
        }
        
        if (rejectedAccounts.isEmpty()) return;
        
        List<Id> processInstanceIds = new List<Id>();
        
        List<Account> accsWithPI = [
            SELECT (SELECT Id FROM ProcessInstances ORDER BY CreatedDate DESC LIMIT 1)
            FROM Account
            WHERE Id IN :rejectedAccounts.keySet()
        ];
        
        for (Account acc : accsWithPI) {
            if (!acc.ProcessInstances.isEmpty()) {
                processInstanceIds.add(acc.ProcessInstances[0].Id);
            }
        }
        
        if (processInstanceIds.isEmpty()) return;
        
        List<ProcessInstance> processInstances = [
            SELECT TargetObjectId,
            (SELECT Id, StepStatus, Comments FROM Steps WHERE StepStatus = 'Rejected' ORDER BY CreatedDate DESC LIMIT 1)
            FROM ProcessInstance
            WHERE Id IN :processInstanceIds
        ];
        System.debug('Step: '+processInstances);
        
        for (ProcessInstance pi : processInstances) {
            System.debug('pi.Steps[0].Comments'+pi.Steps[0].Comments);
            if (
                pi.Steps.isEmpty() ||
                pi.Steps[0].Comments == null ||
                pi.Steps[0].Comments.trim().length() == 0
            ) {
                rejectedAccounts.get(pi.TargetObjectId).addError('Please provide a rejection reason!');
            }
        }
    }
    
    public static void validateReassignmentComments(List<Account> newList, Map<Id, Account> oldMap) {
        Map<Id, Account> recalledAccounts = new Map<Id, Account>();
        
        // Identify records where Recall__c changed to true
        for (Account acc : newList) {
            Account oldAcc = oldMap.get(acc.Id);
            
            if (
                oldAcc != null &&
                oldAcc.Recall__c != true &&
                acc.Recall__c == true
            ) {
                recalledAccounts.put(acc.Id, acc);
            }
        }
        
        if (recalledAccounts.isEmpty()) return;
        
        // Fetch latest process instance for recalled records
        List<Id> processInstanceIds = new List<Id>();
        List<Account> accsWithPI = [
            SELECT (SELECT Id FROM ProcessInstances ORDER BY CreatedDate DESC LIMIT 1)
            FROM Account
            WHERE Id IN :recalledAccounts.keySet()
        ];
        
        for (Account acc : accsWithPI) {
            if (!acc.ProcessInstances.isEmpty()) {
                processInstanceIds.add(acc.ProcessInstances[0].Id);
            }
        }
        
        if (processInstanceIds.isEmpty()) return;
        
        List<ProcessInstance> processInstances = [
            SELECT TargetObjectId,
            (SELECT Id, StepStatus, Comments FROM Steps WHERE StepStatus = 'Reassigned' ORDER BY CreatedDate DESC LIMIT 1)
            FROM ProcessInstance
            WHERE Id IN :processInstanceIds
        ];
        system.debug('processInstances: '+processInstances);
        for (ProcessInstance pi : processInstances) {
            system.debug('pi.Steps[0].Comments-->'+pi.Steps[0].Comments);
            if (
                pi.Steps.isEmpty() ||
                pi.Steps[0].Comments == null ||
                pi.Steps[0].Comments.trim().length() == 0
            ) {
                recalledAccounts.get(pi.TargetObjectId).addError('Please provide a reason for reassignment!');
            } else {
                // Mark Recall__c as false after successful validation
                recalledAccounts.get(pi.TargetObjectId).Recall__c = false;
            }
        }
    } 
    
    
}