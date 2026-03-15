/**
* @description REST service for creating or updating Product2 records in Salesforce based on external product data.
* Accepts a JSON array of product details, checks for existing products by ProductCode (Material),
* and performs an upsert operation. Validates for duplicate Material codes and ensures no fields are blank in the request.
* Logs API calls and responses in API_LOG__c custom object.
* Handles bulk operations efficiently to stay within governor limits.
* @author Gowsic N
* @date 2025-08-12
* @endpoint POST /services/apexrest/product/v1/*
* @param JSON body - Array of ProductWrapper objects containing product details
* @return List of ResponseWrapper objects with success status, message, and Material
* @throws Exceptions for invalid JSON, duplicate Material codes, blank field errors, or DML failures
* @codeCoverage ProductRestServiceTest (94%)
*/
@RestResource(urlMapping='/product/v1/*')
global with sharing class ProductRestService {
    /**
* @description Wrapper class to deserialize JSON input for product data.
*/
    global class ProductWrapper {
        public String Material;
        public String Material_Description;
        public String Material_Type;
        public String Material_Group;
        public String Base_Unit_of_Measure;
        public String MRP_Type;
        public String Valuation_Class;
        public String Price_Control;
        public String Currency_Code;
        public String HSN_Code;
        public String Plant;
        public String Material_Blocked;
    }
    /**
* @description Wrapper class to structure the API response.
*/
    global class ResponseWrapper {
        public String success;
        public String message;
        public String material;
        public String plant;
        
        public ResponseWrapper(String success, String message, String material, String plant) {
            this.success = success;
            this.message = message;
            this.material = material;
            this.plant = plant;
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
* @description Validates a single ProductWrapper for blank fields.
* @param wrapper The ProductWrapper to validate.
* @return String containing validation error message, or empty string if valid.
*/
    private static String validateProductWrapper(ProductWrapper wrapper) {
        String errorMessage = '';
        // Blank field validations
        if (String.isBlank(wrapper.Plant)) {
            errorMessage += 'Plant is required; ';
        }
        else if (wrapper.Plant.length() > 255) {
            errorMessage += 'Plant must not exceed 255 characters; ';
        }
        if (String.isBlank(wrapper.Material)) {
            errorMessage += 'Material is required; ';
        }
        else if (wrapper.Material.length() > 255) {
            errorMessage += 'Material must not exceed 255 characters; ';
        }
        if (String.isBlank(wrapper.Material_Description)) {
            errorMessage += 'Material_Description is required; ';
        }
        else if (wrapper.Material_Description.length() > 4000) {
            errorMessage += 'Material_Description must not exceed 4000 characters; ';
        }
        if (String.isBlank(wrapper.Material_Type)) {
            errorMessage += 'Material_Type is required; ';
        }
        if (String.isBlank(wrapper.Material_Group)) {
            errorMessage += 'Material_Group is required; ';
        }
        if (String.isBlank(wrapper.Base_Unit_of_Measure)) {
            errorMessage += 'Base_Unit_of_Measure is required; ';
        }
        if (String.isBlank(wrapper.MRP_Type)) {
            errorMessage += 'MRP_Type is required; ';
        }
        if (String.isBlank(wrapper.Valuation_Class)) {
            errorMessage += 'Valuation_Class is required; ';
        }
        if (String.isBlank(wrapper.Price_Control)) {
            errorMessage += 'Price_Control is required; ';
        }
        if (String.isBlank(wrapper.Currency_Code)) {
            errorMessage += 'Currency_Code is required; ';
        }
        if (String.isBlank(wrapper.HSN_Code)) {
            errorMessage += 'HSN_Code is required; ';
        }
        else if (wrapper.HSN_Code.length() > 120) {
            errorMessage += 'HSN_Code must not exceed 120 characters; ';
        }
        return errorMessage;
    }
    /**
* @description Handles POST requests to create or update Product2 records.
* checks for existing products by ProductCode, and performs bulk upsert.
* Validates for blank fields and consolidates Products by Material
* Logs the request and response details.
* @return List of ResponseWrapper objects indicating the result of each operation.
*/
  
    @HttpPost
    global static List<ResponseWrapper> createproduct() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String jsonBody = req.requestBody.toString();
        
        List<ResponseWrapper> responseWrappers = new List<ResponseWrapper>();
        List<API_LOG__c> apiLogs = new List<API_LOG__c>();
        Boolean isSuccess = false;
        String errorMessage = '';
        // Check request size
        if (req.requestBody.size() > 6 * 1024 * 1024) { // 6MB limit
            responseWrappers.add(new ResponseWrapper('false', 'Request size exceeds 6MB limit', null, null));
            res.statusCode = 400;
            
            API_LOG__c apiLog = new API_LOG__c(
                Status__c = 'Failure',
                Error__c = 'Request size exceeds 6MB limit',
                Method__c = 'POST',
                Scope__c = 'ProductInbound',
                Status_Code__c = String.valueOf(res.statusCode)
            );
            insert apiLog;
            handleLargeText(apiLog, 'Request__c', jsonBody, 'Excess Request', 'Request_File_Link__c');
            handleLargeText(apiLog, 'Response__c', JSON.serialize(responseWrappers), 'Excess Response', 'Response_File_Link__c');
            apiLogs.add(apiLog);
            return responseWrappers;
        }
        
        try {
            // Deserialize JSON into a list of ProductWrapper objects
            List<ProductWrapper> wrappers = (List<ProductWrapper>) JSON.deserialize(jsonBody, List<ProductWrapper>.class);
            
            
            
            // Validate each ProductWrapper for blank fields
            for (ProductWrapper wrapper : wrappers) {
                String validationError = validateProductWrapper(wrapper);
                if (String.isNotBlank(validationError)) {
                    errorMessage += 'Validation failed for Material ' + (String.isNotBlank(wrapper.Material) ? wrapper.Material : 'unknown') + ': ' + validationError + '; ';
                    responseWrappers.add(new ResponseWrapper('false', validationError, wrapper.Material, 'null'));
                    
                }
            }
            // If any validation errors, return early
            if (!responseWrappers.isEmpty()) {
                res.statusCode = 400;
                isSuccess = false;
                return responseWrappers;
            }
            
            // Collect Material codes for querying existing Products
            Set<String> materialCodes = new Set<String>();
            
            
            // Collect Material codes for querying existing Products
            for (ProductWrapper wrapper : wrappers) {
                if (String.isNotBlank(wrapper.Material)) {
                    materialCodes.add(wrapper.Material);
                }
            }
            
            //List<Product2> productsToUpsert = new List<Product2>();
            Map<String, Product2> productMap = new Map<String, Product2>();            
            
            // Fetch existing products using both ProductCode and Plant__c
            Map<String, Product2> existingProductsByMaterial  = new Map<String, Product2>();
            for (Product2 prod : [
                SELECT Id, ProductCode, Plant__c, Material_Blocked__c
                FROM Product2
                WHERE ProductCode IN :materialCodes
            ]) {
                existingProductsByMaterial.put(prod.ProductCode, prod);
            }
            
            for (ProductWrapper wrapper : wrappers) {
                
                Product2 product;
                
                // If already processed this Material → reuse same Product2
                if (productMap.containsKey(wrapper.Material)) {
                    product = productMap.get(wrapper.Material);
                } else {
                    // Existing product
                    if (existingProductsByMaterial.containsKey(wrapper.Material)) {
                        product = existingProductsByMaterial.get(wrapper.Material);
                    } 
                    // New product
                    else {
                        product = new Product2();
                        product.ProductCode = wrapper.Material;
                    }
                    
                    productMap.put(wrapper.Material, product);
                }
                
                // Map fields (will override with latest values – same as before)
                product.Name = wrapper.Material_Description;
                product.Description = wrapper.Material_Description;
                product.Product_Type__c = wrapper.Material_Type;
                product.Group_Code__c = wrapper.Material_Group;
                product.QuantityUnitOfMeasure = wrapper.Base_Unit_of_Measure;
                product.MRP_Type__c = wrapper.MRP_Type;
                product.Valuation_Class__c = wrapper.Valuation_Class;
                product.Price_Control__c = wrapper.Price_Control;
                product.CurrencyIsoCode = wrapper.Currency_Code;
                product.HSN_code__c = wrapper.HSN_Code;
                product.Material_Blocked__c = wrapper.Material_Blocked;
                
                //Merge Plant safely
                product.Plant__c = mergeMultiSelect(product.Plant__c, wrapper.Plant);
            }
            
            
            // Perform upsert operation
            List<Product2> productsToUpsert = productMap.values();
            
            if (!productsToUpsert.isEmpty()) {
                
                // Use Id for updates and insert new records without external ID
                List<Database.UpsertResult> upsertResults =
                    Database.upsert(productsToUpsert, false);
                
                // Process upsert results (PER PRODUCT, NOT PER WRAPPER)
                for (Integer i = 0; i < upsertResults.size(); i++) {
                    
                    Database.UpsertResult ur = upsertResults[i];
                    Product2 prod = productsToUpsert[i];
                    
                    if (ur.isSuccess()) {
                        responseWrappers.add(new ResponseWrapper(
                            'true',
                            ur.isCreated()
                            ? 'Record Inserted Successfully.'
                            : 'Record Updated Successfully.',
                            prod.ProductCode,
                            prod.Plant__c
                        ));
                    } else {
                        String errorMsg = ur.getErrors()[0].getMessage();
                        responseWrappers.add(new ResponseWrapper(
                            'false',
                            'Operation Failed: ' + errorMsg,
                            prod.ProductCode,
                            prod.Plant__c
                        ));
                        errorMessage +=
                            'Product ' + prod.ProductCode + ': ' + errorMsg + '; ';
                    }
                }
            }
            
            isSuccess = true;
            res.statusCode = 200;
            
        } catch(Exception e) {
            System.debug('Exception: ' + e.getMessage());
            errorMessage = e.getMessage();
            responseWrappers.add(new ResponseWrapper('false', 'Operation Failed: ' + errorMessage, null, null));
            res.statusCode = 500;
            
            
        }
        
        // Log the API call
        API_LOG__c apiLog = new API_LOG__c(
            Status__c = isSuccess ? 'Success' : 'Failure',
            Error__c = errorMessage,
            Method__c = 'POST',
            Scope__c = 'ProductInbound',
            Status_Code__c = String.valueOf(res.statusCode)
        );
        insert apiLog;
        handleLargeText(apiLog, 'Request__c', jsonBody, 'Excess Request', 'Request_File_Link__c');
        handleLargeText(apiLog, 'Response__c', JSON.serialize(responseWrappers), 'Excess Response', 'Response_File_Link__c');
        apiLogs.add(apiLog);
        
        // Update all API logs to ensure Request__c and Response__c are persisted
        if (!apiLogs.isEmpty()) {
            update apiLogs;
        }
        
        return responseWrappers;
    }
    
    private static String mergeMultiSelect(String existingValue, String incomingValue) {
        if (String.isBlank(incomingValue)) {
            return existingValue;
        }
        if (String.isBlank(existingValue)) {
            return incomingValue;
        }
        
        Set<String> values = new Set<String>();
        values.addAll(existingValue.split(';'));
        values.addAll(incomingValue.split(';'));
        
        return String.join(new List<String>(values), ';');
    }
}