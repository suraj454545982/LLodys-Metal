public class LedgerBalanceService {

    public static SAPResponseWrapper getLedgerBalance(
        LedgerBalanceRequestWrapper requestWrapper
    ){

        return SAPLedgerBalanceIntegration.callSAPLedgerBalanceAPI(requestWrapper);

    }

}