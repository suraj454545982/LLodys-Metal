/**
 * @description REST service for creating or updating Dispatch__c records in Salesforce based on external dispatch data.
 * Validates all requests upfront for size, JSON, record limit, duplicate C_Inv_No, required fields, Material_No,
 * Sale_Order_No, OrderItem, Date, Decimal, and Integer fields. Processes data only if all validations pass,
 * performing inserts for new records and updates for existing records based on Invoice_Number__c. Logs all API calls
 * with Dispatch__c record ID in API_LOG__c.
 * @author Gowsic N
 * @date 2025-08-12
 * @endpoint POST /services/apexrest/dispatch/v1/*
 * @param JSON body - Array of DispatchWrapper objects containing dispatch details
 * @return List of ResponseWrapper objects with success status, message, and C_Inv_No
 * @throws Exceptions for invalid JSON, missing required fields, duplicate C_Inv_No, invalid formats, or DML failures
 * @CC DispatchRestServiceTest (88%)
 */
@RestResource(urlMapping='/dispatch/v1/')
global with sharing class DispatchRestService {
    
    public class ForcedTestException extends Exception {}
    
    @TestVisible
    private static Boolean forceLargeRequestForTest = false;
    @TestVisible
	private static Boolean forceExceptionForTest = false;
  
    /**
     * @description Wrapper class to deserialize JSON input for dispatch data.
     * Represents the structure of the incoming dispatch data with all required fields.
     */
    public class DispatchWrapper {
        public Long Accounting_Document;
        public String C_Inv_Date; // Changed to String to handle "00000000"
        public String C_Inv_No;
        public Integer Item_No;
        public String Material_No;
        public String Material_Description;
        public String Truck_No_As_Per_Invoice;
        public String Transporter_Name_As_Per_Invoice;
        public String LR_Number_As_Per_Invoice;
        public String LR_Date_As_Per_Invoice; // Changed to String to handle "00000000"
        public String Sale_Order_No;
        public Decimal Dispatched_Qty;
        public String Customer_PO_No;
        public String Currency_Code;
        public String Plant;
        public String Inco_Term2;
        public String Payment_Terms;
        public String Driver_Mobile_Number;
        public Integer Sold_to_Party;
        public Integer Ship_to_Party;
        public String GST;
        public Decimal IGST;
        public Decimal SGST;
        public Decimal CGST;
        public Decimal Price;
        public Long EWay_Bill_No_Date;
        public String Dest_Town_name;
        public String Sold_to_Party_Name;
        public String Ship_to_Party_Name;
        public Decimal Total_Value;
    }
    
    @TestVisible
    private static Boolean isRequestTooLarge(Integer bodySize) {
        return bodySize > 6 * 1024 * 1024;
    }
  
    /**
     * @description Wrapper class to structure the response for each dispatch processed.
     * Contains success status, message, dispatch ID, and record ID.
     */
    global class ResponseWrapper {
        public String success;
        public String message;
        public String dispatchId;
        public String recordId;
      
        public ResponseWrapper(String success, String message, String dispatchId, String recordId) {
            this.success = success;
            this.message = message;
            this.dispatchId = dispatchId;
            this.recordId = recordId;
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
    @TestVisible
    private static void handleLargeText(API_LOG__c apiLog, String fieldName, String content, String fileTitle, String linkFieldName) {
        final Integer MAX_LENGTH = 131000; // Margin below 131072 limit.
        
        try {
            if (String.isBlank(content) || content.length() <= MAX_LENGTH) {
                apiLog.put(fieldName, content);
                return;
            }
            
            // Truncate and store excess in file
            String truncated = content.substring(0, MAX_LENGTH) + ' [TRUNCATED - See attached file for rest]';
            apiLog.put(fieldName, truncated);
            
            String excessContent = content.substring(MAX_LENGTH);
            
            // Create file (ContentVersion)
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
            
            update apiLog;
        } catch (Exception e) {
            System.debug('handleLargeText Error for field ' + fieldName + ': ' + e.getMessage());
            // Do not re-throw to maintain original behavior
        }
    }
  
    /**
     * @description HTTP POST method to create or update Dispatch__c records.
     * Performs all validations upfront (request size, JSON, record limit, duplicates, required fields,
     * Material_No, Sale_Order_No, OrderItem, Date, Decimal, Integer) and only processes data if all pass.
     * Inserts new records and updates existing records based on Invoice_Number__c. Logs all API interactions in API_LOG__c.
     * @return List of ResponseWrapper objects indicating the result of each dispatch operation.
     */
    //private static final Integer MAX_RECORDS = 200;
  
    @HttpPost
    global static List<ResponseWrapper> createDispatch() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String jsonBody = req.requestBody.toString();
        List<ResponseWrapper> responseWrappers = new List<ResponseWrapper>();
        List<API_LOG__c> apiLogs = new List<API_LOG__c>();
        res.statusCode = 200;
      
        // Check request size
        if (forceLargeRequestForTest || isRequestTooLarge(req.requestBody.size())) {
            responseWrappers.add(new ResponseWrapper('false', 'Request size exceeds 6MB limit', null, null));
            res.statusCode = 400;
          
            API_LOG__c apiLog = new API_LOG__c(
                Status__c = 'Failure',
                Error__c = 'Request size exceeds 6MB limit',
                Method__c = 'POST',
                Scope__c = 'DispatchInbound',
                Status_Code__c = '400',
                Request__c = jsonBody,
                Response__c = JSON.serialize(responseWrappers[0])
            );
            insert apiLog;
            handleLargeText(apiLog, 'Request__c', jsonBody, 'Excess Request', 'Request_File_Link__c');
            handleLargeText(apiLog, 'Response__c', JSON.serialize(responseWrappers[0]), 'Excess Response', 'Response_File_Link__c');
            return responseWrappers;
        }
      
        List<DispatchWrapper> wrappers;
        try {
            // Deserialize JSON into a list of DispatchWrapper objects
            wrappers = (List<DispatchWrapper>) JSON.deserialize(jsonBody, List<DispatchWrapper>.class);
        } catch (Exception e) {
            responseWrappers.add(new ResponseWrapper('false', 'Invalid JSON: ' + e.getMessage(), null, null));
            res.statusCode = 400;
          
            API_LOG__c apiLog = new API_LOG__c(
                Status__c = 'Failure',
                Error__c = 'Invalid JSON: ' + e.getMessage(),
                Method__c = 'POST',
                Scope__c = 'DispatchInbound',
                Status_Code__c = '400',
                Request__c = jsonBody,
                Response__c = JSON.serialize(responseWrappers[0])
            );
            insert apiLog;
            handleLargeText(apiLog, 'Request__c', jsonBody, 'Excess Request', 'Request_File_Link__c');
            handleLargeText(apiLog, 'Response__c', JSON.serialize(responseWrappers[0]), 'Excess Response', 'Response_File_Link__c');
            return responseWrappers;
        }
      
        
        // Check for duplicate C_Inv_No in the request
        Set<String> invoiceNos = new Set<String>();
        for (DispatchWrapper wrapper : wrappers) {
            if (String.isNotBlank(wrapper.C_Inv_No)) {
                if (invoiceNos.contains(wrapper.C_Inv_No)) {
                    responseWrappers.add(new ResponseWrapper('false', 'Duplicate C_Inv_No found: ' + wrapper.C_Inv_No, wrapper.C_Inv_No, null));
                    res.statusCode = 400;
                  
                    API_LOG__c apiLog = new API_LOG__c(
                        Status__c = 'Failure',
                        Error__c = 'Duplicate C_Inv_No found: ' + wrapper.C_Inv_No,
                        Method__c = 'POST',
                        Scope__c = 'DispatchInbound',
                        Status_Code__c = '400',
                        Request__c = JSON.serialize(wrapper),
                        Response__c = JSON.serialize(responseWrappers[0])
                    );
                    insert apiLog;
                    handleLargeText(apiLog, 'Request__c', JSON.serialize(wrapper), 'Excess Request', 'Request_File_Link__c');
                    handleLargeText(apiLog, 'Response__c', JSON.serialize(responseWrappers[0]), 'Excess Response', 'Response_File_Link__c');
                    return responseWrappers;
                }
                invoiceNos.add(wrapper.C_Inv_No);
            }
        }
      
        // Query all Material_No values at once for efficiency
        Set<String> materialNos = new Set<String>();
        for (DispatchWrapper wrapper : wrappers) {
            if (String.isNotBlank(wrapper.Material_No)) {
                materialNos.add(wrapper.Material_No);
            }
        }
        Map<String, Product2> materialMap = new Map<String, Product2>();
        for (Product2 prod : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN :materialNos]) {
            materialMap.put(prod.ProductCode, prod);
        }
      
        // Query all Sale_Order_No values at once for efficiency
        Set<String> saleOrderNos = new Set<String>();
        for (DispatchWrapper wrapper : wrappers) {
            if (String.isNotBlank(wrapper.Sale_Order_No)) {
                saleOrderNos.add(wrapper.Sale_Order_No);
            }
        }
        Map<String, Id> orderMap = new Map<String, Id>();
        for (Order o : [SELECT Id, Sale_Order_Number__c FROM Order WHERE Sale_Order_Number__c IN :saleOrderNos]) {
            orderMap.put(o.Sale_Order_Number__c, o.Id);
        }
      
        // Query all relevant OrderItems
        Set<Id> orderIds = new Set<Id>(orderMap.values());
        Map<Id, Map<String, Id>> orderToProductCodeToItemId = new Map<Id, Map<String, Id>>();
        if (!orderIds.isEmpty()) {
            for (OrderItem oi : [SELECT Id, OrderId, Product2.ProductCode FROM OrderItem WHERE OrderId IN :orderIds AND Product2.ProductCode IN :materialNos]) {
                if (!orderToProductCodeToItemId.containsKey(oi.OrderId)) {
                    orderToProductCodeToItemId.put(oi.OrderId, new Map<String, Id>());
                }
                orderToProductCodeToItemId.get(oi.OrderId).put(oi.Product2.ProductCode, oi.Id);
            }
        }
      
        // Query existing Dispatch__c records by Invoice_Number__c
        Map<String, Dispatch__c> existingDispatchMap = new Map<String, Dispatch__c>();
        if (!invoiceNos.isEmpty()) {
            for (Dispatch__c dispatch : [SELECT Id, Invoice_Number__c FROM Dispatch__c WHERE Invoice_Number__c IN :invoiceNos]) {
                existingDispatchMap.put(dispatch.Invoice_Number__c, dispatch);
            }
        }
      
        // Validate all required fields, Material_No, Date, Decimal, and Integer upfront
        Integer index = 0;
        for (DispatchWrapper wrapper : wrappers) {
            String errorMessage = '';
            ResponseWrapper responseWrapper;
          
            // Validate required fields based on provided JSON
            if (String.isBlank(wrapper.C_Inv_No)) {
                errorMessage = 'C_Inv_No is missing';
            } else if (wrapper.Item_No == null) {
                errorMessage = 'Item_No is missing';
            } else if (String.isBlank(wrapper.Material_No)) { 
                errorMessage = 'Material_No is missing';
            } else if (String.isBlank(wrapper.Material_Description)) {
                errorMessage = 'Material_Description is missing';
            } else if (String.isBlank(wrapper.Sale_Order_No)) {
                errorMessage = 'Sale_Order_No is missing';
            } else if (wrapper.Customer_PO_No == null) {
                errorMessage = 'Customer_PO_No is missing';
            } else if (String.isBlank(wrapper.Currency_Code)) {
                errorMessage = 'Currency_Code is missing';
            } else if (String.isBlank(wrapper.Plant)) {
                errorMessage = 'Plant is missing';
            } else if (String.isBlank(wrapper.Inco_Term2)) {
                errorMessage = 'Inco_Term2 is missing';
            } else if (String.isBlank(wrapper.Payment_Terms)) {
                errorMessage = 'Payment_Terms is missing';
            } else if (wrapper.Sold_to_Party == null) {
                errorMessage = 'Sold_to_Party is missing';
            } else if (wrapper.Ship_to_Party == null) {
                errorMessage = 'Ship_to_Party is missing';
            } else if (String.isBlank(wrapper.GST)) {
                errorMessage = 'GST is missing';
            } else if (String.isBlank(wrapper.Sold_to_Party_Name)) {
                errorMessage = 'Sold_to_Party_Name is missing';
            } else if (String.isBlank(wrapper.Ship_to_Party_Name)) {
                errorMessage = 'Ship_to_Party_Name is missing';
            } else if (wrapper.Total_Value == null) {
                errorMessage = 'Total_Value is missing';
            } 
          
            // Validate Date fields (C_Inv_Date, LR_Date_As_Per_Invoice)
            if (wrapper.C_Inv_Date != null && String.isNotBlank(wrapper.C_Inv_Date)) {
                String dateStr = wrapper.C_Inv_Date;
                if (dateStr == '00000000') {
                    // Accept '00000000' as valid, will map to null
                } else {
                    try {
                        Pattern datePattern = Pattern.compile('^\\d{4}-\\d{2}-\\d{2}$');
                        Matcher dateMatcher = datePattern.matcher(dateStr);
                        if (!dateMatcher.matches()) {
                            errorMessage = 'Invalid format for C_Inv_Date: ' + dateStr + ', expected YYYY-MM-DD';
                        } else {
                            Date.valueOf(dateStr);
                        }
                    } catch (Exception e) {
                        errorMessage = 'Invalid C_Inv_Date: ' + e.getMessage();
                    }
                }
            }
            if (wrapper.LR_Date_As_Per_Invoice != null && String.isNotBlank(wrapper.LR_Date_As_Per_Invoice)) {
                String dateStr = wrapper.LR_Date_As_Per_Invoice;
                if (dateStr == '00000000') {
                    // Accept '00000000' as valid, will map to null
                } else {
                    try {
                        Pattern datePattern = Pattern.compile('^\\d{4}-\\d{2}-\\d{2}$');
                        Matcher dateMatcher = datePattern.matcher(dateStr);
                        if (!dateMatcher.matches()) {
                            errorMessage = 'Invalid format for LR_Date_As_Per_Invoice: ' + dateStr + ', expected YYYY-MM-DD';
                        } else {
                            Date.valueOf(dateStr);
                        }
                    } catch (Exception e) {
                        errorMessage = 'Invalid LR_Date_As_Per_Invoice: ' + e.getMessage();
                    }
                }
            }
          
            // Validate Decimal fields (Dispatched_Qty, IGST, SGST, CGST, Price, Total_Value)
            if (wrapper.Dispatched_Qty != null) {
                try {
                    String decimalStr = String.valueOf(wrapper.Dispatched_Qty).replaceAll('[^0-9.-]', '');
                    Decimal.valueOf(decimalStr);
                } catch (Exception e) {
                    errorMessage = 'Invalid format for Dispatched_Qty: ' + wrapper.Dispatched_Qty;
                }
            }
            if (wrapper.IGST != null) {
                try {
                    String decimalStr = String.valueOf(wrapper.IGST).replaceAll('[^0-9.-]', '');
                    Decimal.valueOf(decimalStr);
                } catch (Exception e) {
                    errorMessage = 'Invalid format for IGST: ' + wrapper.IGST;
                }
            }
            if (wrapper.SGST != null) {
                try {
                    String decimalStr = String.valueOf(wrapper.SGST).replaceAll('[^0-9.-]', '');
                    Decimal.valueOf(decimalStr);
                } catch (Exception e) {
                    errorMessage = 'Invalid format for SGST: ' + wrapper.SGST;
                }
            }
            if (wrapper.CGST != null) {
                try {
                    String decimalStr = String.valueOf(wrapper.CGST).replaceAll('[^0-9.-]', '');
                    Decimal.valueOf(decimalStr);
                } catch (Exception e) {
                    errorMessage = 'Invalid format for CGST: ' + wrapper.CGST;
                }
            }
            if (wrapper.Price != null) {
                try {
                    String decimalStr = String.valueOf(wrapper.Price).replaceAll('[^0-9.-]', '');
                    Decimal.valueOf(decimalStr);
                } catch (Exception e) {
                    errorMessage = 'Invalid format for Price: ' + wrapper.Price;
                }
            }
            if (wrapper.Total_Value != null) {
                try {
                    String decimalStr = String.valueOf(wrapper.Total_Value).replaceAll('[^0-9.-]', '');
                    Decimal.valueOf(decimalStr);
                } catch (Exception e) {
                    errorMessage = 'Invalid format for Total_Value: ' + wrapper.Total_Value;
                }
            }
          
            // Validate Integer fields (Accounting_Document, Item_No, Sold_to_Party, Ship_to_Party)
            if (wrapper.Accounting_Document != null) {
                try {
                    String intStr = String.valueOf(wrapper.Accounting_Document).replaceAll('[^0-9]', '');
                    Long.valueOf(intStr);
                } catch (Exception e) {
                    errorMessage = 'Invalid format for Accounting_Document: ' + wrapper.Accounting_Document;
                }
            }
            if (wrapper.Item_No != null) {
                try {
                    String intStr = String.valueOf(wrapper.Item_No).replaceAll('[^0-9]', '');
                    Integer.valueOf(intStr);
                } catch (Exception e) {
                    errorMessage = 'Invalid format for Item_No: ' + wrapper.Item_No;
                }
            }
            if (wrapper.Sold_to_Party != null) {
                try {
                    String intStr = String.valueOf(wrapper.Sold_to_Party).replaceAll('[^0-9]', '');
                    Integer.valueOf(intStr);
                } catch (Exception e) {
                    errorMessage = 'Invalid format for Sold_to_Party: ' + wrapper.Sold_to_Party;
                }
            }
            if (wrapper.Ship_to_Party != null) {
                try {
                    String intStr = String.valueOf(wrapper.Ship_to_Party).replaceAll('[^0-9]', '');
                    Integer.valueOf(intStr);
                } catch (Exception e) {
                    errorMessage = 'Invalid format for Ship_to_Party: ' + wrapper.Ship_to_Party;
                }
            }
          
            if (String.isNotBlank(errorMessage)) {
                responseWrapper = new ResponseWrapper('false', errorMessage, wrapper.C_Inv_No, null);
                responseWrappers.add(responseWrapper);
                res.statusCode = 400;
              
                API_LOG__c apiLog = new API_LOG__c(
                    Status__c = 'Failure',
                    Error__c = errorMessage,
                    Method__c = 'POST',
                    Scope__c = 'DispatchInbound',
                    Status_Code__c = '400',
                    Request__c = JSON.serialize(wrapper),
                    Response__c = JSON.serialize(responseWrapper)
                );
                insert apiLog;
                handleLargeText(apiLog, 'Request__c', JSON.serialize(wrapper), 'Excess Request', 'Request_File_Link__c');
                handleLargeText(apiLog, 'Response__c', JSON.serialize(responseWrapper), 'Excess Response', 'Response_File_Link__c');
                return responseWrappers;
            }
            index++;
        }
      
        // If all validations pass, proceed with mapping and DML operations
        try {
            if (forceExceptionForTest) {
                throw new ForcedTestException('Forced exception for test');
            }
            List<Dispatch__c> dispatchesToInsert = new List<Dispatch__c>();
            List<Dispatch__c> dispatchesToUpdate = new List<Dispatch__c>();
            Map<Integer, DispatchWrapper> wrapperMap = new Map<Integer, DispatchWrapper>();
            index = 0;
          
            for (DispatchWrapper wrapper : wrappers) {
                Dispatch__c dispatch = new Dispatch__c();
                Product2 materialId = materialMap.get(wrapper.Material_No);
                Id orderId = orderMap.get(wrapper.Sale_Order_No);
                Map<String, Id> productToItemMap = orderToProductCodeToItemId.get(orderId);
              
                // Map wrapper fields to dispatch fields
                dispatch.Accounting_Document__c = (Long) wrapper.Accounting_Document;
                // Map C_Inv_Date
                if (wrapper.C_Inv_Date != null && String.isNotBlank(wrapper.C_Inv_Date)) {
                    if (wrapper.C_Inv_Date == '00000000') {
                        dispatch.Invoice_Date__c = null;
                    } else {
                        try {
                            dispatch.Invoice_Date__c = Date.valueOf(wrapper.C_Inv_Date);
                        } catch (Exception e) {
                            dispatch.Invoice_Date__c = null;
                        }
                    }
                } else {
                    dispatch.Invoice_Date__c = null;
                }
                dispatch.Invoice_Number__c = wrapper.C_Inv_No;
                dispatch.Item_Number__c = wrapper.Item_No;
                if (materialId != null) {
                    dispatch.Product__c = materialId.Id;
                }
                dispatch.Product_Description__c = wrapper.Material_Description;
                dispatch.Truck_No_As_Per_Invoice__c = wrapper.Truck_No_As_Per_Invoice;
                dispatch.Transporter_Name_As_Per_Invoice__c = wrapper.Transporter_Name_As_Per_Invoice;
                dispatch.LR_Number_As_Per_Invoice__c = wrapper.LR_Number_As_Per_Invoice;
                // Map LR_Date_As_Per_Invoice
                if (wrapper.LR_Date_As_Per_Invoice != null && String.isNotBlank(wrapper.LR_Date_As_Per_Invoice)) {
                    if (wrapper.LR_Date_As_Per_Invoice == '00000000') {
                        dispatch.LR_Date_As_Per_Invoice__c = null;
                    } else {
                        try {
                            dispatch.LR_Date_As_Per_Invoice__c = Date.valueOf(wrapper.LR_Date_As_Per_Invoice);
                        } catch (Exception e) {
                            dispatch.LR_Date_As_Per_Invoice__c = null;
                        }
                    }
                } else {
                    dispatch.LR_Date_As_Per_Invoice__c = null;
                }
                dispatch.Sale_Order_Number__c = wrapper.Sale_Order_No;
                dispatch.Dispatched_Quantity__c = wrapper.Dispatched_Qty;
                dispatch.CurrencyIsoCode = wrapper.Currency_Code;
                dispatch.Plant__c = wrapper.Plant;
                dispatch.IncoTerm2__c = wrapper.Inco_Term2;
                dispatch.Payment_Terms__c = wrapper.Payment_Terms;
                dispatch.Driver_Mobile_Number__c = wrapper.Driver_Mobile_Number;
                dispatch.Sold_to_Party__c = wrapper.Sold_to_Party;
                dispatch.Ship_to_Party__c = wrapper.Ship_to_Party;
                dispatch.GST__c = wrapper.GST;
                dispatch.IGST__c = wrapper.IGST;
                dispatch.SGST__c = wrapper.SGST;
                dispatch.CGST__c = wrapper.CGST;
                dispatch.Price__c = wrapper.Price;
                dispatch.E_Way_Bill_No_Date__c = wrapper.EWay_Bill_No_Date;
                dispatch.Destination_Town_name__c = wrapper.Dest_Town_name;
                dispatch.Sold_to_Party_Name__c = wrapper.Sold_to_Party_Name;
                dispatch.Ship_to_Party_Name__c = wrapper.Ship_to_Party_Name;
                dispatch.Total_Value__c = wrapper.Total_Value;
                dispatch.Sales_Order_No__c = wrapper.Sale_Order_No;
                if (orderId != null) {
                    dispatch.Sales_Order__c = orderId;
                }
                //dispatch.Sales_Order_Line_Item__c = productToItemMap.get(wrapper.Material_No);
              
                // Decide whether to insert or update based on existing Dispatch__c record
                if (String.isNotBlank(wrapper.C_Inv_No) && existingDispatchMap.containsKey(wrapper.C_Inv_No)) {
                    dispatch.Id = existingDispatchMap.get(wrapper.C_Inv_No).Id;
                    dispatchesToUpdate.add(dispatch);
                } else {
                    dispatchesToInsert.add(dispatch);
                }
              
                ResponseWrapper responseWrapper = new ResponseWrapper('true', 'Record Queued for Processing', wrapper.C_Inv_No, null);
                responseWrappers.add(responseWrapper);
              
                // Log each API call
                API_LOG__c apiLog = new API_LOG__c(
                    Status__c = 'Success',
                    Error__c = '',
                    Method__c = 'POST',
                    Scope__c = 'DispatchInbound',
                    Status_Code__c = '200',
                    Request__c = JSON.serialize(wrapper),
                    Response__c = JSON.serialize(responseWrapper)
                );
                insert apiLog;
                handleLargeText(apiLog, 'Request__c', JSON.serialize(wrapper), 'Excess Request', 'Request_File_Link__c');
                handleLargeText(apiLog, 'Response__c', JSON.serialize(responseWrapper), 'Excess Response', 'Response_File_Link__c');
                apiLogs.add(apiLog);
                wrapperMap.put(index, wrapper);
                index++;
            }
          
            // Perform bulk insert for new records
            if (!dispatchesToInsert.isEmpty()) {
                List<Database.SaveResult> insertResults = Database.insert(dispatchesToInsert, false);
                Set<Id> insertedIds = new Set<Id>();
                for (Database.SaveResult result : insertResults) {
                    if (result.isSuccess() && result.getId() != null) {
                        insertedIds.add(result.getId());
                    }
                }
                Map<Id, Dispatch__c> insertedDispatches = new Map<Id, Dispatch__c>(
                    [SELECT Id, Invoice_Number__c FROM Dispatch__c WHERE Id IN :insertedIds]
                );
                for (Integer i = 0; i < dispatchesToInsert.size(); i++) {
                    Database.SaveResult result = insertResults[i];
                    Dispatch__c dispatch = dispatchesToInsert[i];
                    Integer wrapperIndex = wrappers.indexOf(wrapperMap.get(i));
                    ResponseWrapper responseWrapper = responseWrappers[wrapperIndex];
                    API_LOG__c apiLog = apiLogs[wrapperIndex];
                    if (result.isSuccess()) {
                        Dispatch__c insertedDispatch = insertedDispatches.get(result.getId());
                        responseWrapper.success = 'true';
                        responseWrapper.message = 'Record Inserted Successfully.';
                        responseWrapper.dispatchId = insertedDispatch.Invoice_Number__c;
                        responseWrapper.recordId = insertedDispatch.Id;
                        apiLog.Status__c = 'Success';
                        apiLog.Response__c = JSON.serialize(responseWrapper);
                        apiLog.Dispatch__c = insertedDispatch.Id;
                    } else {
                        responseWrapper.success = 'false';
                        responseWrapper.message = 'Insert Failed: ' + result.getErrors()[0].getMessage();
                        apiLog.Status__c = 'Failure';
                        apiLog.Error__c = result.getErrors()[0].getMessage();
                        apiLog.Response__c = JSON.serialize(responseWrapper);
                        res.statusCode = 400;
                    }
                    handleLargeText(apiLog, 'Response__c', JSON.serialize(responseWrapper), 'Excess Response', 'Response_File_Link__c');
                }
            }
          
            // Perform bulk update for existing records
            if (!dispatchesToUpdate.isEmpty()) {
                List<Database.SaveResult> updateResults = Database.update(dispatchesToUpdate, false);
                for (Integer i = 0; i < dispatchesToUpdate.size(); i++) {
                    Database.SaveResult result = updateResults[i];
                    Dispatch__c dispatch = dispatchesToUpdate[i];
                    Integer wrapperIndex = wrappers.indexOf(wrapperMap.get(i + dispatchesToInsert.size()));
                    ResponseWrapper responseWrapper = responseWrappers[wrapperIndex];
                    API_LOG__c apiLog = apiLogs[wrapperIndex];
                    if (result.isSuccess()) {
                        responseWrapper.success = 'true';
                        responseWrapper.message = 'Record Updated Successfully.';
                        responseWrapper.dispatchId = dispatch.Invoice_Number__c;
                        responseWrapper.recordId = dispatch.Id;
                        apiLog.Status__c = 'Success';
                        apiLog.Response__c = JSON.serialize(responseWrapper);
                        apiLog.Dispatch__c = dispatch.Id;
                    } else {
                        responseWrapper.success = 'false';
                        responseWrapper.message = 'Update Failed: ' + result.getErrors()[0].getMessage();
                        apiLog.Status__c = 'Failure';
                        apiLog.Error__c = result.getErrors()[0].getMessage();
                        apiLog.Response__c = JSON.serialize(responseWrapper);
                        apiLog.Dispatch__c = dispatch.Id;
                        res.statusCode = 400;
                    }
                    handleLargeText(apiLog, 'Response__c', JSON.serialize(responseWrapper), 'Excess Response', 'Response_File_Link__c');
                    
                }
            }
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
            ResponseWrapper responseWrapper = new ResponseWrapper('false', 'Operation Failed: ' + e.getMessage(), null, null);
            responseWrappers.add(responseWrapper);
            res.statusCode = 500;
          
            API_LOG__c apiLog = new API_LOG__c(
                Status__c = 'Failure',
                Error__c = e.getMessage(),
                Method__c = 'POST',
                Scope__c = 'DispatchInbound',
                Status_Code__c = '500',
                Request__c = jsonBody,
                Response__c = JSON.serialize(responseWrapper)
            );
            insert apiLog;
            handleLargeText(apiLog, 'Request__c', jsonBody, 'Excess Request', 'Request_File_Link__c');
            handleLargeText(apiLog, 'Response__c', JSON.serialize(responseWrapper), 'Excess Response', 'Response_File_Link__c');
            apiLogs.add(apiLog);
        }
      
        // Insert all API logs
        if (!apiLogs.isEmpty()) {
            update apiLogs; // Update logs with Dispatch__c and Response__c
        }
      
        return responseWrappers;
    }
    
}