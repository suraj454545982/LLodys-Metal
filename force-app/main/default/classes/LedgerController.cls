public class LedgerController {
    
    @AuraEnabled
    public static SAPResponseWrapper fetchLedgerData(String requestWrapperJson){
        
        System.debug('String requestWrapperJson from LWC'+requestWrapperJson);
        
        LedgerRequestWrapper requestWrapper =
            (LedgerRequestWrapper) JSON.deserialize(requestWrapperJson, LedgerRequestWrapper.class);
        
		System.debug(requestWrapper.Customer_Account);
        System.debug(requestWrapper.Company_Code);
        System.debug(requestWrapper.Posting_Date);
        return LedgerService.getLedgerData(requestWrapper);

    }
}