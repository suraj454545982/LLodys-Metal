public class SurveyService {
    public static void updateSurveyUrlsWithCommunityBase(List<Id> surveyIds) {
        System.debug('updateSurveyUrlsWithCommunityBase started with surveyIds: ' + surveyIds);
        
        if (surveyIds == null || surveyIds.isEmpty()) {
            System.debug('No surveyIds provided, exiting method.');
            return;
        }
        
        String orgDomainUrl = URL.getOrgDomainUrl().toExternalForm();
        System.debug('Org domain URL: ' + orgDomainUrl);
        
        String baseUrl = orgDomainUrl;
        if (orgDomainUrl.contains('.salesforce.com')) {
            baseUrl = orgDomainUrl.replace('.salesforce.com', '.site.com');
        } else if (orgDomainUrl.contains('lightning.force.com')) {
            // Fix typo 'ightning' -> 'lightning'
            baseUrl = orgDomainUrl.replace('lightning.force.com', 'site.com');
        } else {
            baseUrl = orgDomainUrl;
        }
        
        System.debug('Computed baseUrl: ' + baseUrl);
        
        // Query surveys to update URL and send emails
        List<Survey__c> surveysToUpdate = [
            SELECT Id, Unique_ID__c, URL__c, Email_Id__c, Account_Name__c,status__c,ismail__c,
            Account__r.Additional_Mails__c,Otp_Verification__c
            FROM Survey__c
            WHERE Id IN :surveyIds
        ];
        
        // Update URL__c based on Unique_ID__c
        for (Survey__c s : surveysToUpdate) {
            if (String.isNotBlank(s.Unique_ID__c)) {
                s.URL__c = baseUrl + '/s/surveyform?UNI=' + s.Unique_ID__c;
                s.Status__c = 'Sent';
                System.debug('Updated survey URL for Survey Id ' + s.Id + ': ' + s.URL__c);
            } else {
                System.debug('Unique_ID__c is blank for Survey Id ' + s.Id);
            }
        }
        
        if (!surveysToUpdate.isEmpty()) {
            update surveysToUpdate;
            System.debug('Surveys updated successfully.');
        }
        
        // --- EMAIL SENDING LOGIC STARTS HERE ---
        
        // Query the email template (replace 'Feedback Email' with your template name)
        EmailTemplate template = [
            SELECT HtmlValue, Subject
            FROM EmailTemplate
            WHERE Name = 'Feedback Email'
            LIMIT 1
        ];
        
        String htmlTemplate = template.HtmlValue;
        String subjectTemplate = template.Subject;
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<String> toAddresses =  new List<String>();
        for (Survey__c survey : surveysToUpdate) {
            if (String.isNotBlank(survey.Email_Id__c) && survey.ismail__c) {
                String htmlBody = htmlTemplate;
                // Replace merge fields — add more as needed
                htmlBody = htmlBody.replace('{!Survey__c.Account_Name__c}', survey.Account_Name__c != null ? survey.Account_Name__c : '');
                String url = survey.URL__c != null ? survey.URL__c : '#';
                String clickableLink = '<a href="' + url + '" target="_blank" style="color: #0066cc; text-decoration: underline;">Click here to submit your feedback</a>';
                htmlBody = htmlBody.replace('{otp}', survey.Otp_Verification__c);  
                htmlBody = htmlBody.replace('{Link}', clickableLink);
                String subject = subjectTemplate.replace('{!Survey__c.Account_Name__c}', survey.Account_Name__c != null ? survey.Account_Name__c : '');
                
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                 toAddresses = new List<String>{ survey.Email_Id__c };
                    if (survey.Account__r != null && String.isNotBlank(survey.Account__r.Additional_Mails__c)) {
                        List<String> additionalEmails = survey.Account__r.Additional_Mails__c.split('[,;\\s]+');
                        for (String email : additionalEmails) {
                            if (!String.isBlank(email)) {
                                toAddresses.add(email.trim());
                            }
                        }
                    }
                
                mail.setToAddresses(toAddresses);
                mail.setSubject(subject);
                mail.setHtmlBody(htmlBody);
                mail.setSaveAsActivity(false);
                emails.add(mail);
            }
        }
        
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
            System.debug('Feedback emails sent: ' + emails.size());
        } else {
            System.debug('No emails to send - no valid Email_Id__c found.');
        }
    }
    
}