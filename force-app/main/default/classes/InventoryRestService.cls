/**
 * @description REST service for creating or updating Inventory__c records in Salesforce based on external inventory data.
 * Accepts a JSON array of inventory details, validates Material codes against Product2, checks for duplicate
 * Material/Plant/Storage_Location combinations (case-insensitive), and performs bulk upsert operations.
 * Records are identified by Material/Plant/Storage_Location combination: updates if the combination exists,
 * inserts if it does not. Logs API calls and responses in API_LOG__c custom object.
 * @author Gowsic N
 * @date 2025-08-12
 * @endpoint POST /services/apexrest/inventory/v1/*
 * @param JSON body - Array of InventoryWrapper objects containing inventory details
 * @return List of ResponseWrapper objects with success status, message, and Salesforce Id
 * @throws Exceptions for invalid JSON, duplicate Material/Plant/Storage_Location combinations, missing required fields,
 * invalid Material, or DML failures
 * @CC InventoryRestServiceTest
 */
@RestResource(urlMapping='/inventory/v1/*')
global with sharing class InventoryRestService {
    /**
     * @description Wrapper class to deserialize JSON input for inventory data.
     */
    public class InventoryWrapper {
        public String Material;
        public String Plant;
        public String Storage_Location;
        public Decimal Qty;
    }
    /**
     * @description Wrapper class to structure the API response.
     */
    global class ResponseWrapper {
        public String success;
        public String message;
        public String material;
        public String Plant;
        public String Storage_Location;
        public ResponseWrapper(String success, String message, String material, String Plant, String Storage_Location) {
            this.success = success;
            this.message = message;
            this.material = material;
            this.Plant = Plant;
            this.Storage_Location = Storage_Location;
        }
    }
    /**
     * @description Helper to handle large text for API_LOG__c fields. Truncates if needed, attaches excess as a file, and sets URL link.
     * @param apiLog The API_LOG__c record (must be inserted before calling this if attaching files).
     * @param fieldName The field to set (e.g., 'Request__c' or 'Response__c').
     * @param content The full string content.
     * @param fileTitle The title for the attached file (e.g., 'Excess Request Content').
     * @param linkFieldName The URL field to update (e.g., 'Request_File_Link__c').
     */
    private static void handleLargeText(API_LOG__c apiLog, String fieldName, String content, String fileTitle, String linkFieldName) {
        final Integer MAX_LENGTH = 131000; // Margin below 131072 limit.
        
        if (String.isBlank(content) || content.length() <= MAX_LENGTH) {
            apiLog.put(fieldName, content);
            return;
        }
        
        // Truncate and store excess in file
        String truncated = content.substring(0, MAX_LENGTH) + ' [TRUNCATED - See attached file for rest]';
        apiLog.put(fieldName, truncated);
        
        String excessContent = content.substring(MAX_LENGTH);
        
        // Create file (ContentVersion)
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = fileTitle;
            cv.PathOnClient = fileTitle + '.txt';
            cv.VersionData = Blob.valueOf(excessContent);
            cv.FirstPublishLocationId = apiLog.Id; // Attaches to the API_LOG__c record
            insert cv;
            
            // Query to get ContentDocumentId (required for URL)
            cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            
            // Set URL link
            String baseUrl = System.URL.getOrgDomainUrl().toExternalForm();
            String fileUrl = baseUrl + '/lightning/r/ContentDocument/' + cv.ContentDocumentId + '/view';
            apiLog.put(linkFieldName, fileUrl);
        } catch (Exception e) {
            System.debug('Error in handleLargeText while creating ContentVersion: ' + e.getMessage());
            apiLog.Error__c = (String.isBlank(apiLog.Error__c) ? '' : apiLog.Error__c + '; ') + 'Failed to attach file for ' + fieldName + ': ' + e.getMessage();
        }
        
        try {
            update apiLog;
        } catch (Exception e) {
            System.debug('Error in handleLargeText while updating API_LOG__c: ' + e.getMessage());
            apiLog.Error__c = (String.isBlank(apiLog.Error__c) ? '' : apiLog.Error__c + '; ') + 'Failed to update log for ' + fieldName + ': ' + e.getMessage();
        }
    }
    /**
     * @description Handles POST requests to create or update Inventory__c records.
     * Validates required fields, checks for duplicate Material/Plant/Storage_Location combinations (case-insensitive),
     * verifies Material against Product2, and performs bulk upsert based on Material/Plant/Storage_Location.
     * Logs the request and response details.
     * @return List of ResponseWrapper objects indicating the result of each operation.
     */
    private static final Integer MAX_RECORDS = 200;
    private static final Integer MAX_REQUEST_SIZE = 6 * 1024 * 1024; // 6MB limit
    private static final Integer MAX_FIELD_LENGTH = 255; // Character limit for Plant and Storage_Location
    private static final Integer MAX_NAME_LENGTH = 80; // Salesforce Name field limit
    @HttpPost
    global static List<ResponseWrapper> createInventory() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String jsonBody = req.requestBody.toString();
        List<ResponseWrapper> responseWrappers = new List<ResponseWrapper>();
        List<API_LOG__c> apiLogs = new List<API_LOG__c>();
        Boolean isSuccess = false;
        String errorMessage = '';
        // Check request size
        if (req.requestBody.size() > MAX_REQUEST_SIZE) {
            responseWrappers.add(new ResponseWrapper('false', 'Request size exceeds 6MB limit', null, null, null));
            res.statusCode = 400;
            API_LOG__c apiLog = logAndReturn(responseWrappers, jsonBody, 'Failure', 'Request size exceeds 6MB limit', 'POST', 'InventoryInbound', res.statusCode);
            apiLogs.add(apiLog);
            return responseWrappers;
        }
        try {
            // Deserialize JSON into a list of InventoryWrapper objects
            List<InventoryWrapper> wrappers = (List<InventoryWrapper>) JSON.deserialize(jsonBody, List<InventoryWrapper>.class);
            // Validate list size
            /*if (wrappers.size() > MAX_RECORDS) {
                responseWrappers.add(new ResponseWrapper('false', 'Request exceeds maximum limit of ' + MAX_RECORDS + ' records', null, null, null));
                res.statusCode = 400;
                API_LOG__c apiLog = logAndReturn(responseWrappers, jsonBody, 'Failure', 'Request exceeds maximum limit of ' + MAX_RECORDS + ' records', 'POST', 'InventoryInbound', res.statusCode);
                apiLogs.add(apiLog);
                return responseWrappers;
            }*/
            // Collect data for validation
            Set<String> compositeKeys = new Set<String>();
            Set<String> duplicateCompositeKeys = new Set<String>();
            Set<String> materialCodes = new Set<String>();
            Set<String> plants = new Set<String>();
            Set<String> storageLocations = new Set<String>();
            Map<Integer, InventoryWrapper> wrapperIndexMap = new Map<Integer, InventoryWrapper>();
            for (Integer i = 0; i < wrappers.size(); i++) {
                InventoryWrapper wrapper = wrappers[i];
                if (String.isNotBlank(wrapper.Material)) materialCodes.add(wrapper.Material);
                if (String.isNotBlank(wrapper.Plant)) plants.add(wrapper.Plant);
                if (String.isNotBlank(wrapper.Storage_Location)) storageLocations.add(wrapper.Storage_Location);
                wrapperIndexMap.put(i, wrapper);
                // Check for duplicates within the request (case-insensitive)
                if (String.isNotBlank(wrapper.Material) && String.isNotBlank(wrapper.Plant) && String.isNotBlank(wrapper.Storage_Location)) {
                    String compositeKey = wrapper.Material.toUpperCase() + '|' + wrapper.Plant.toUpperCase() + '|' + wrapper.Storage_Location.toUpperCase();
                    if (compositeKeys.contains(compositeKey)) {
                        duplicateCompositeKeys.add(compositeKey);
                    } else {
                        compositeKeys.add(compositeKey);
                    }
                }
            }
            // If duplicates found in request, return error
            if (!duplicateCompositeKeys.isEmpty()) {
                errorMessage = 'Duplicate Material/Plant/Storage_Location combinations found: ' + String.join(new List<String>(duplicateCompositeKeys), ', ');
                responseWrappers.add(new ResponseWrapper('false', errorMessage, null, null, null));
                res.statusCode = 400;
                API_LOG__c apiLog = logAndReturn(responseWrappers, jsonBody, 'Failure', errorMessage, 'POST', 'InventoryInbound', res.statusCode);
                apiLogs.add(apiLog);
                return responseWrappers;
            }
            // Query Product2 records for Material codes
            Map<String, Product2> materialMap = new Map<String, Product2>();
            for (Product2 prod : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN :materialCodes]) {
                materialMap.put(prod.ProductCode, prod);
            }
            // Query existing Inventory__c records by composite key
            Map<String, Inventory__c> existingInventoriesByCompositeKey = new Map<String, Inventory__c>();
            for (Inventory__c inv : [SELECT Id, product__c, Plant__c, Storage_Location__c, product__r.ProductCode
                                    FROM Inventory__c
                                    WHERE product__r.ProductCode IN :materialCodes
                                    AND Plant__c IN :plants
                                    AND Storage_Location__c IN :storageLocations]) {
                String compositeKey = inv.product__r.ProductCode.toUpperCase() + '|' + inv.Plant__c.toUpperCase() + '|' + inv.Storage_Location__c.toUpperCase();
                existingInventoriesByCompositeKey.put(compositeKey, inv);
            }
            List<Inventory__c> inventoriesToUpsert = new List<Inventory__c>();
            // Process each wrapper
            for (Integer i = 0; i < wrappers.size(); i++) {
                InventoryWrapper wrapper = wrappers[i];
                // Validate required fields
                if (String.isBlank(wrapper.Material)) {
                    responseWrappers.add(new ResponseWrapper('false', 'Material is missing for index: ' + i, null, null, null));
                    errorMessage += 'Material is missing for index: ' + i + '; ';
                    API_LOG__c apiLog = logAndReturn(responseWrappers, jsonBody, 'Failure', 'Material is missing for index: ' + i, 'POST', 'InventoryInbound', 400);
                    apiLogs.add(apiLog);
                    continue;
                }
                if (String.isBlank(wrapper.Plant)) {
                    responseWrappers.add(new ResponseWrapper('false', 'Plant is missing for Material: ' + wrapper.Material, null, null, null));
                    errorMessage += 'Plant is missing for Material: ' + wrapper.Material + '; ';
                    API_LOG__c apiLog = logAndReturn(responseWrappers, jsonBody, 'Failure', 'Plant is missing for Material: ' + wrapper.Material, 'POST', 'InventoryInbound', 400);
                    apiLogs.add(apiLog);
                    continue;
                }
                if (wrapper.Plant.length() > MAX_FIELD_LENGTH) {
                    responseWrappers.add(new ResponseWrapper('false', 'Plant exceeds 255 character limit for Material: ' + wrapper.Material, null, null, null));
                    errorMessage += 'Plant exceeds 255 character limit for Material: ' + wrapper.Material + '; ';
                    API_LOG__c apiLog = logAndReturn(responseWrappers, jsonBody, 'Failure', 'Plant exceeds 255 character limit for Material: ' + wrapper.Material, 'POST', 'InventoryInbound', 400);
                    apiLogs.add(apiLog);
                    continue;
                }
                if (String.isBlank(wrapper.Storage_Location)) {
                    responseWrappers.add(new ResponseWrapper('false', 'Storage_Location is missing for Material: ' + wrapper.Material, null, wrapper.Plant, null));
                    errorMessage += 'Storage_Location is missing for Material: ' + wrapper.Material + '; ';
                    API_LOG__c apiLog = logAndReturn(responseWrappers, jsonBody, 'Failure', 'Storage_Location is missing for Material: ' + wrapper.Material, 'POST', 'InventoryInbound', 400);
                    apiLogs.add(apiLog);
                    continue;
                }
                if (wrapper.Storage_Location.length() > MAX_FIELD_LENGTH) {
                    responseWrappers.add(new ResponseWrapper('false', 'Storage_Location exceeds 255 character limit for Material: ' + wrapper.Material, null, null, null));
                    errorMessage += 'Storage_Location exceeds 255 character limit for Material: ' + wrapper.Material + '; ';
                    API_LOG__c apiLog = logAndReturn(responseWrappers, jsonBody, 'Failure', 'Storage_Location exceeds 255 character limit for Material: ' + wrapper.Material, 'POST', 'InventoryInbound', 400);
                    apiLogs.add(apiLog);
                    continue;
                }
                if (wrapper.Qty == null) {
                    responseWrappers.add(new ResponseWrapper('false', 'Qty is missing for Material: ' + wrapper.Material, null, null, null));
                    errorMessage += 'Qty is missing for Material: ' + wrapper.Material + '; ';
                    API_LOG__c apiLog = logAndReturn(responseWrappers, jsonBody, 'Failure', 'Qty is missing for Material: ' + wrapper.Material, 'POST', 'InventoryInbound', 400);
                    apiLogs.add(apiLog);
                    continue;
                }
                if (!materialMap.containsKey(wrapper.Material)) {
                    responseWrappers.add(new ResponseWrapper('false', 'No record found for Material: ' + wrapper.Material, null, null, null));
                    errorMessage += 'No record found for Material: ' + wrapper.Material + '; ';
                    API_LOG__c apiLog = logAndReturn(responseWrappers, jsonBody, 'Failure', 'No record found for Material: ' + wrapper.Material, 'POST', 'InventoryInbound', 400);
                    apiLogs.add(apiLog);
                    continue;
                }
                Inventory__c inventory = new Inventory__c();
                inventory.product__c = materialMap.get(wrapper.Material).Id;
                inventory.Plant__c = wrapper.Plant;
                inventory.Storage_Location__c = wrapper.Storage_Location;
                inventory.Quantity__c = wrapper.Qty;
                // Check for existing record by Material/Plant/Storage_Location
                String compositeKey = wrapper.Material.toUpperCase() + '|' + wrapper.Plant.toUpperCase() + '|' + wrapper.Storage_Location.toUpperCase();
                if (existingInventoriesByCompositeKey.containsKey(compositeKey)) {
                    inventory.Id = existingInventoriesByCompositeKey.get(compositeKey).Id;
                }
                inventoriesToUpsert.add(inventory);
            }
            // Perform upsert operation
            if (!inventoriesToUpsert.isEmpty()) {
                List<Database.UpsertResult> upsertResults = Database.upsert(inventoriesToUpsert, Inventory__c.Id, false);
                // Collect IDs of successfully upserted inventories
                Set<Id> upsertedInventoryIds = new Set<Id>();
                for (Integer i = 0; i < upsertResults.size(); i++) {
                    if (upsertResults[i].isSuccess()) {
                        upsertedInventoryIds.add(inventoriesToUpsert[i].Id);
                    }
                }
                // Query updated inventories for Ids
                Map<Id, Inventory__c> updatedInventories = new Map<Id, Inventory__c>([
                    SELECT Id, product__r.ProductCode, Plant__c, Storage_Location__c
                    FROM Inventory__c
                    WHERE Id IN :upsertedInventoryIds
                ]);
                // Process upsert results
                for (Integer i = 0; i < upsertResults.size(); i++) {
                    Database.UpsertResult ur = upsertResults[i];
                    InventoryWrapper wrapper = wrapperIndexMap.get(i);
                    Inventory__c inventory = inventoriesToUpsert[i];
                    if (ur.isSuccess()) {
                        Inventory__c updatedInventory = updatedInventories.get(inventory.Id);
                        responseWrappers.add(new ResponseWrapper(
                            'true',
                            ur.isCreated() ? 'Inventory Inserted Successfully.' : 'Inventory Updated Successfully.',
                            updatedInventory != null ? updatedInventory.product__r.ProductCode : wrapper.Material,
                            wrapper.Plant,
                            wrapper.Storage_Location
                        ));
                    } else {
                        String errorMsg = ur.getErrors()[0].getMessage();
                        responseWrappers.add(new ResponseWrapper(
                            'false',
                            'Operation Failed for Material ' + wrapper.Material + ': ' + errorMsg,
                            null, null, null
                        ));
                        errorMessage += 'Operation Failed for Material ' + wrapper.Material + ': ' + errorMsg + '; ';
                        API_LOG__c apiLog = logAndReturn(responseWrappers, jsonBody, 'Failure', 'Operation Failed for Material ' + wrapper.Material + ': ' + errorMsg, 'POST', 'InventoryInbound', 400);
                        apiLogs.add(apiLog);
                    }
                }
            }
            // Set response status
            if (responseWrappers.isEmpty() && !String.isEmpty(errorMessage)) {
                responseWrappers.add(new ResponseWrapper('false', 'No valid records processed: ' + summarizeErrors(errorMessage), null, null, null));
                res.statusCode = 400;
                API_LOG__c apiLog = logAndReturn(responseWrappers, jsonBody, 'Failure', 'No valid records processed: ' + summarizeErrors(errorMessage), 'POST', 'InventoryInbound', res.statusCode);
                apiLogs.add(apiLog);
            } else if (!responseWrappers.isEmpty()) {
                isSuccess = true;
                res.statusCode = 200;
                API_LOG__c apiLog = logAndReturn(responseWrappers, jsonBody, 'Success', summarizeErrors(errorMessage), 'POST', 'InventoryInbound', res.statusCode);
                apiLogs.add(apiLog);
            }
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
            errorMessage = e.getMessage();
            responseWrappers.add(new ResponseWrapper('false', 'Operation Failed: ' + errorMessage, null, null, null));
            res.statusCode = 500;
            API_LOG__c apiLog = logAndReturn(responseWrappers, jsonBody, 'Failure', errorMessage, 'POST', 'InventoryInbound', res.statusCode);
            apiLogs.add(apiLog);
        }
        // Update all API logs to ensure Request__c and Response__c are persisted
        if (!apiLogs.isEmpty()) {
            update apiLogs;
        }
        return responseWrappers;
    }
    /**
     * @description Logs the API call details to API_LOG__c and returns the response.
     * @param responseWrappers List of response wrappers to return
     * @param jsonBody Request body
     * @param status Success or Failure
     * @param errorMessage Error message to log
     * @param method HTTP method
     * @param scope API scope
     * @param statusCode HTTP status code
     * @return API_LOG__c object for further processing
     */
    private static API_LOG__c logAndReturn(List<ResponseWrapper> responseWrappers, String jsonBody, String status, String errorMessage, String method, String scope, Integer statusCode) {
        API_LOG__c apiLog = new API_LOG__c(
            Status__c = status,
            Error__c = errorMessage,
            Method__c = method,
            Scope__c = scope,
            Status_Code__c = String.valueOf(statusCode)
        );
        insert apiLog;
        handleLargeText(apiLog, 'Request__c', jsonBody, 'Excess Request', 'Request_File_Link__c');
        handleLargeText(apiLog, 'Response__c', JSON.serialize(responseWrappers), 'Excess Response', 'Response_File_Link__c');
        return apiLog;
    }
    /**
     * @description Summarizes error messages by grouping and counting duplicates.
     * @param errorMessage Raw error message string
     * @return Summarized error message
     */
    private static String summarizeErrors(String errorMessage) {
        if (String.isBlank(errorMessage)) return '';
        Map<String, Integer> errorCounts = new Map<String, Integer>();
        for (String err : errorMessage.split(';')) {
            if (String.isNotBlank(err.trim())) {
                errorCounts.put(err.trim(), errorCounts.get(err.trim()) == null ? 1 : errorCounts.get(err.trim()) + 1);
            }
        }
        String summarizedError = '';
        for (String err : errorCounts.keySet()) {
            summarizedError += err + ' (Occurred ' + errorCounts.get(err) + ' times); ';
        }
        return summarizedError;
    }
}