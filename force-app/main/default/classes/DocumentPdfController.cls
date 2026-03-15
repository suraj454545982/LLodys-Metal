public with sharing class DocumentPdfController {

    @AuraEnabled
    public static String fetchDocumentPdf(
        String customer,
        String companyCode,
        String documentNumber,
        String postingDate
    ){

        // Create Request Wrapper
        DocumentPdfRequestWrapper requestWrapper = new DocumentPdfRequestWrapper();
        requestWrapper.Customer = customer;
        requestWrapper.Company_code = companyCode;
        requestWrapper.Document_Number = documentNumber;
        requestWrapper.Posting_date = postingDate;

        // Call Service
        SAPResponseWrapper response =
            SAPDocumentPdfIntegration.callSAPDocumentPdfAPI(requestWrapper);

        // If API success
        if(response.status == 'Success' && String.isNotBlank(response.responseBody)){

            DocumentPdfResponseWrapper pdfResponse =
                (DocumentPdfResponseWrapper)
                JSON.deserialize(response.responseBody, DocumentPdfResponseWrapper.class);

            return pdfResponse.Base64_PDF;
        }

        throw new AuraHandledException('Failed to fetch PDF');

    }

}