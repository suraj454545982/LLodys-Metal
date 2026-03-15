/**
 * @description SAP → Salesforce: Account Block/Unblock API (Minimal 2-field) + DEBUG
 * @author Simon Christopher
 * @date 2025-11-18
 * @endpoint POST /services/apexrest/customer/block/v1/
 */
@RestResource(urlMapping='/customer/block/v1/*')
global without sharing class AccountBlockUnblock {

    global class CustomerWrapper {
        public String SAP_Account_Number;
        public String Account_Blocked;
    }

    global class ResponseWrapper {
        public String success;
        public String message;
        public String sapAccountNumber;
        public String salesforceAccountId;
        public ResponseWrapper(String success, String message, String sapAccountNumber, String salesforceAccountId) {
            this.success = success;
            this.message = message;
            this.sapAccountNumber = sapAccountNumber;
            this.salesforceAccountId = salesforceAccountId;
        }
    }

    private static void handleLargeText(API_LOG__c apiLog, String fieldName, String content, String fileTitle, String linkFieldName) {
        final Integer MAX_LENGTH = 131000;
        if (String.isBlank(content) || content.length() <= MAX_LENGTH) {
            apiLog.put(fieldName, content);
            return;
        }
        String truncated = content.substring(0, MAX_LENGTH) + ' [TRUNCATED - See attached file]';
        String excess = content.substring(MAX_LENGTH);
        try {
            ContentVersion cv = new ContentVersion(
                Title = fileTitle,
                PathOnClient = fileTitle + '.txt',
                VersionData = Blob.valueOf(excess),
                FirstPublishLocationId = apiLog.Id
            );
            insert cv;
            cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            String baseUrl = URL.getOrgDomainUrl().toExternalForm();
            String fileUrl = baseUrl + '/lightning/r/ContentDocument/' + cv.ContentDocumentId + '/view';
            apiLog.put(linkFieldName, fileUrl);
        } catch (Exception e) {
            apiLog.Error__c = (apiLog.Error__c == null ? '' : apiLog.Error__c + '; ') + 'File attach error: ' + e.getMessage();
        }
        apiLog.put(fieldName, truncated);
        try { update apiLog; } catch (Exception e) {}
    }

    @HttpPost
    global static List<ResponseWrapper> blockUnblockAccounts() {

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String jsonBody = req.requestBody != null ? req.requestBody.toString() : '';

        System.debug('ACCOUNT BLOCK API CALLED');
        System.debug('Raw Request Body: ' + jsonBody);

        List<ResponseWrapper> responses = new List<ResponseWrapper>();
        List<API_LOG__c> apiLogs = new List<API_LOG__c>();

        Boolean isSuccess = false;
        String globalError = '';

        try {

            if (String.isBlank(jsonBody)) {
                throw new IllegalArgumentException('Request body is empty');
            }

            List<CustomerWrapper> wrappers = (List<CustomerWrapper>) JSON.deserialize(jsonBody, List<CustomerWrapper>.class);

            if (wrappers.isEmpty()) {
                throw new IllegalArgumentException('No records in request');
            }

            Set<String> sapCodes = new Set<String>();
            res.statusCode = 200;

            // VALIDATION
            for (CustomerWrapper w : wrappers) {

                if (String.isBlank(w.SAP_Account_Number)) {
                    responses.add(new ResponseWrapper('false', 'SAP_Account_Number is required', null, null));
                    res.statusCode = 200;
                    continue;
                }
                if (String.isBlank(w.Account_Blocked) ||
                    (!w.Account_Blocked.equalsIgnoreCase('Yes') &&
                     !w.Account_Blocked.equalsIgnoreCase('No'))) {
                    responses.add(new ResponseWrapper('false', 'Account_Blocked must be "Yes" or "No"', w.SAP_Account_Number, null));
                    continue;
                }
                if (!sapCodes.add(w.SAP_Account_Number)) {
                    responses.add(new ResponseWrapper('false', 'Duplicate SAP_Account_Number: ' + w.SAP_Account_Number, w.SAP_Account_Number, null));
                }
            }

            // QUERY
            Map<String, Account> accountMap = new Map<String, Account>();
            for (Account a : [
                SELECT Id, Name, SAP_Customer_Code__c, Customer_Blocked__c
                FROM Account
                WHERE SAP_Customer_Code__c IN :sapCodes
            ]) {
                accountMap.put(a.SAP_Customer_Code__c, a);
            }

            List<Account> toUpdate = new List<Account>();

            // Temporary mapping for DML results later
            Map<Id, String> desiredValues = new Map<Id, String>();

            // PREPARE RESPONSE (success will be overwritten after DML)
            for (CustomerWrapper w : wrappers) {

                Account acc = accountMap.get(w.SAP_Account_Number);

                if (acc == null) {
                    responses.add(new ResponseWrapper('false', 'Account not found in Salesforce', w.SAP_Account_Number, null));
                    continue;
                }

                String desiredValue = w.Account_Blocked.equalsIgnoreCase('Yes') ? 'Yes' : 'No';

                // Track desired values for later DML result update
                desiredValues.put(acc.Id, desiredValue);

                if (acc.Customer_Blocked__c != desiredValue) {
                    acc.Customer_Blocked__c = desiredValue;
                    toUpdate.add(acc);
                }

                // TEMP — will fix after DML results
                responses.add(new ResponseWrapper('false', 'Pending update', w.SAP_Account_Number, acc.Id));
            }

            // PERFORM DML
            Database.SaveResult[] results = new List<Database.SaveResult>();

            if (!toUpdate.isEmpty()) {
                results = Database.update(toUpdate, false);
            }

            // DETERMINE SUCCESS OF EACH RECORD
            Map<Id, Boolean> dmlStatus = new Map<Id, Boolean>();

            for (Integer i = 0; i < results.size(); i++) {
                dmlStatus.put(results[i].getId(), results[i].isSuccess());
            }

            // FIX RESPONSES BASED ON DML RESULT
            for (ResponseWrapper r : responses) {

                if (r.salesforceAccountId == null) {
                    continue;
                }

                Boolean status = dmlStatus.containsKey(r.salesforceAccountId) ? dmlStatus.get(r.salesforceAccountId) : true;

                if (status) {
                    r.success = 'true';
                    r.message = (desiredValues.get(r.salesforceAccountId) == 'Yes')
                        ? 'Account blocked successfully'
                        : 'Account unblocked successfully';
                } else {
                    r.success = 'false';
                    r.message = 'Update failed.';
                }
            }

            isSuccess = !dmlStatus.values().contains(false);

        } catch (Exception e) {

            globalError = e.getMessage();
            if (responses.isEmpty()) {
                responses.add(new ResponseWrapper('false', 'Update failed.', null, null));
            }

            res.statusCode = 200; // ALWAYS 200 for option B
        }

        // LOGGING
        API_LOG__c apiLog = new API_LOG__c(
            Status__c = isSuccess ? 'Success' : 'Failure',
            Error__c = globalError.left(131000),
            Method__c = 'POST',
            Scope__c = 'AccountBlock',
            Status_Code__c = '200'
        );
        insert apiLog;

        handleLargeText(apiLog, 'Request__c', jsonBody, 'Excess Request', 'Request_File_Link__c');
        handleLargeText(apiLog, 'Response__c', JSON.serialize(responses), 'Excess Response', 'Response_File_Link__c');

        apiLogs.add(apiLog);
        if (!apiLogs.isEmpty()) update apiLogs;

        return responses;
    }
}