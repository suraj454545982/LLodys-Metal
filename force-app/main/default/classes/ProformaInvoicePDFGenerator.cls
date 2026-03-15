public without sharing class ProformaInvoicePDFGenerator {

    @InvocableMethod(label='Generate Proforma Invoice PDF')
    public static void generatePDF(List<Id> recordIds) {

        if (recordIds == null || recordIds.isEmpty()) {
            return;
        }

        Id proformaInvoiceId = recordIds[0];

        try {
            //  Get Proforma Invoice Number
            Proforma_Invoice__c pi = [
                SELECT Proforma_Invoice_Number__c
                FROM Proforma_Invoice__c
                WHERE Id = :proformaInvoiceId
                LIMIT 1
            ];

            // Fallback safety
            String invoiceNumber = pi.Proforma_Invoice_Number__c != null
                ? pi.Proforma_Invoice_Number__c
                : String.valueOf(proformaInvoiceId);

            //  Visualforce Page
            PageReference pdfPage = Page.ProformaInvoice;
            pdfPage.getParameters().put('id', proformaInvoiceId);

            //  Generate PDF
                Blob pdfBlob;
                
                if (Test.isRunningTest()) {
                    pdfBlob = Blob.valueOf('TEST_PDF');
                } else {
                    pdfBlob = pdfPage.getContentAsPDF();
                }


            // File Name (Business-friendly)
            String fileName = 'Proforma_Invoice_' + invoiceNumber + '.pdf';

            // Create File
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = pdfBlob;
            insert cv;

            // 🔹 Get ContentDocumentId
            Id contentDocId = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ].ContentDocumentId;

            // 🔹 Link File to Proforma Invoice
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentDocId;
            cdl.LinkedEntityId = proformaInvoiceId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;

        } catch (Exception e) {
            System.debug('PDF Generation Error: ' + e.getMessage());
        }
    }
}