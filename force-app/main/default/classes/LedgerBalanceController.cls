public class LedgerBalanceController {

    @AuraEnabled
    public static SAPResponseWrapper fetchLedgerBalance(String requestWrapperJson){

        LedgerBalanceRequestWrapper requestWrapper =
            (LedgerBalanceRequestWrapper) JSON.deserialize(
                requestWrapperJson,
                LedgerBalanceRequestWrapper.class
            );

        return LedgerBalanceService.getLedgerBalance(requestWrapper);

    }

}