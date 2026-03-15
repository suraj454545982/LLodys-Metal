public class SAPResponseWrapper {
    
    @AuraEnabled public String status;
    @AuraEnabled public String errorMessage;
    @AuraEnabled public Integer statusCode;
    @AuraEnabled public String responseBody;
    @AuraEnabled public Id recordId;
    
    public SAPResponseWrapper(String status, String errorMessage, Integer statusCode, String responseBody, Id recordId) {
        this.status = status;
        this.errorMessage = errorMessage;
        this.statusCode = statusCode;
        this.responseBody = responseBody;
        this.recordId = recordId;
    }
}