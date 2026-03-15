public class LedgerService {
    
    //Sending the Data to make Callout
    public static SAPResponseWrapper getLedgerData(LedgerRequestWrapper requestWrapper){
        System.debug(requestWrapper.Customer_Account);
        System.debug(requestWrapper.Company_Code);
        System.debug(requestWrapper.Posting_Date);
        return SAPLedgerIntegration.callSAPLedgerAPI(requestWrapper);
    }
}