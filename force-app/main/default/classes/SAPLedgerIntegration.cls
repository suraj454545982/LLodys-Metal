public class SAPLedgerIntegration {

    public static SAPResponseWrapper callSAPLedgerAPI(LedgerRequestWrapper requestWrapper){
        
        System.debug(requestWrapper.Customer_Account);
        System.debug(requestWrapper.Company_Code);
        System.debug(requestWrapper.Posting_Date);

        Http http = new Http();
        HttpRequest req = new HttpRequest();

        Lloyds_SFDC_Config__mdt settings = Lloyds_SFDC_Config__mdt.getInstance('Default_Config');
        String endpoint = settings.Ledger_Endpoint__c;

        String requestBody = JSON.serialize(requestWrapper);

        req.setEndpoint('callout:SAP_Named_Credential/' + endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type','application/json');
        req.setBody(requestBody);
        req.setTimeout(120000);

        HttpResponse res;
        String status;
        String errorMessage = '';
        Integer statusCode;
        String responseBody;

        try {

            res = http.send(req);

            statusCode = res.getStatusCode();
            responseBody = res.getBody();

            if(statusCode == 200 || statusCode == 201){
                status = 'Success';
            } else {
                status = 'Failure';
                errorMessage = responseBody;
            }

        }
        catch(Exception ex){

            status = 'Failure';
            statusCode = 500;
            errorMessage = ex.getMessage();
            responseBody = '';

        }

        // ===== API LOG =====

        List<SAPResponseWrapper> wrappers = new List<SAPResponseWrapper>();

        wrappers.add(
            new SAPResponseWrapper(status, errorMessage, statusCode, responseBody, null)
        );

        API_LOG__c log = SalesOrderTriggerHelper.createApiLog(
            wrappers,
            requestBody,
            status,
            errorMessage,
            'POST',
            'LedgerFetch',
            statusCode,
            null,
            responseBody
            
        );

        insert log;

        // ===== RETURN TO LWC =====

        return new SAPResponseWrapper(status,errorMessage,statusCode,responseBody,null);

    }

}