public without sharing class QuoteOfferPDFGenerator {

    @InvocableMethod(label='Generate Quote Offer PDF')
    public static void generatePDF(List<Id> recordIds) {

        if (recordIds == null || recordIds.isEmpty()) {
            return;
        }

        Id quoteId = recordIds[0];

        try {
            // 🔹 Fetch Quote Number
            Quote q = [
                SELECT Quote_Number__c, Name
                FROM Quote
                WHERE Id = :quoteId
                LIMIT 1
            ];

            String quoteNumber = q.Quote_Number__c != null
                ? q.Quote_Number__c
                : q.Name;

            // 🔹 Visualforce Page
            PageReference pdfPage = Page.offerpdf;
            pdfPage.getParameters().put('id', quoteId);

            // 🔹 Generate PDF
            Blob pdfBlob;
            
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('TEST_PDF');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }


            // 🔹 File Name
            String fileName = 'Quote_' + quoteNumber + '.pdf';

            // 🔹 Create File
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

            // 🔹 Link File to Quote
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentDocId;
            cdl.LinkedEntityId = quoteId;
            cdl.ShareType = 'V';        // Viewer
            cdl.Visibility = 'AllUsers';
            insert cdl;

        } catch (Exception e) {
            System.debug('Quote Offer PDF Error: ' + e.getMessage());
        }
    }
}