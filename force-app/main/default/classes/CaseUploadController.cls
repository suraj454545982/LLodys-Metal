public class CaseUploadController {
    /*
    public Case newCase {get; set;}
    public transient Blob fileBlob {get; set;}
    public transient String fileName {get; set;}
    public transient String contentType {get; set;}
    public String retURL {get; set;} // For redirect after submit

    public CaseUploadController() {
        newCase = new Case();
        retURL = ApexPages.currentPage().getParameters().get('retURL'); // Optional: Pass from URL
    }

    public PageReference save() {
        try {
            // Set standard fields (map from form)
            newCase.Subject = newCase.Subject; // From form
            newCase.Description = newCase.Description;
            newCase.Type = newCase.Type;
            newCase.Reason = newCase.Reason; // Assuming "Case Reason" maps to Reason (adjust API name if custom)
            newCase.Origin = 'Web'; // Standard for web submissions

            // Custom field example (replace with actual API name for 00NH400000EWT3B, e.g., Category__c)
            // newCase.Category__c = newCase.Category__c;

            insert newCase;

            // Attach file if uploaded
            if (fileBlob != null && fileName != null) {
                Attachment attach = new Attachment();
                attach.Body = fileBlob;
                attach.Name = fileName;
                attach.ContentType = contentType;
                attach.ParentId = newCase.Id;
                insert attach;
            }

            // Success: Redirect to retURL or a thank-you page
            if (retURL != null) {
                return new PageReference(retURL);
            } else {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Case submitted successfully! Case ID: ' + newCase.Id));
                newCase = new Case(); // Reset form
                return null;
            }
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error: ' + e.getMessage()));
            return null;
        }
    }
    */
}