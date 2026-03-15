public class Emailtest {
    
    public static void sendOfflineJoiningEmails(List<Event> eventList) {
        Set<Id> whatIds = new Set<Id>();
        
        // Step 1: Collect Opportunity Ids from Events
        for (Event e : eventList) {
            if (e.WhatId != null && e.WhatId.getSObjectType() == Opportunity.SObjectType) {
                whatIds.add(e.WhatId);
            }
        }
        
        // Step 2: Query Opportunities with required fields
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(
            [SELECT Id, Contact_Email__c, Joining_Link__c, Category__c FROM Opportunity WHERE Id IN :whatIds]
        );
        
        // Step 3: Collect emails from Opportunities to find matching Contacts
        Set<String> emails = new Set<String>();
        for (Opportunity opp : oppMap.values()) {
            if (String.isNotBlank(opp.Contact_Email__c)) {
                emails.add(opp.Contact_Email__c.toLowerCase());
            }
        }
        
        // Step 4: Query Contacts using the emails
        Map<String, Contact> emailToContactMap = new Map<String, Contact>();
        if (!emails.isEmpty()) {
            List<Contact> contacts = [SELECT Id, Email,Name, Account.Name FROM Contact WHERE Email IN :emails];
            for (Contact c : contacts) {
                emailToContactMap.put(c.Email.toLowerCase(), c);
            }
        }
        
        // Step 5: Query required Email Templates
        Map<String, EmailTemplate> templateNameToId = new Map<String, EmailTemplate>();
        for (EmailTemplate et : [
            SELECT Id, DeveloperName, HtmlValue , Subject FROM EmailTemplate
            WHERE DeveloperName IN ('Plant_visit_Mail_1748250621418', 'Online_meeting_mail_1750067325719')
        ]) {
            templateNameToId.put(et.DeveloperName, et);
        }
        String url = System.Url.getOrgDomainUrl().toExternalForm(); 
        
        // Step 6: Prepare emails
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        User sender = [SELECT Name, Title, Phone, Email FROM User WHERE Id = :UserInfo.getUserId()];
        
        for (Event ev : eventList) {
            Opportunity opp = oppMap.get(ev.WhatId);
            if (opp != null && String.isNotBlank(opp.Contact_Email__c)) {
                Contact contact = emailToContactMap.get(opp.Contact_Email__c.toLowerCase());
                
                if (contact != null) {
                    // Determine which email template to use
                    String joiningType = ev.Joining_through__c != null ? ev.Joining_through__c.toLowerCase() : '';
                    EmailTemplate templateId;
                    
                    if (joiningType == 'online') {
                        templateId = templateNameToId.get('Online_meeting_mail_1750067325719');
                    } else {
                        templateId = templateNameToId.get('Plant_visit_Mail_1748250621418');
                    }
                    
                    if (templateId == null) {
                        System.debug('Template not found for event: ' + ev.Id + ', joiningType: ' + joiningType);
                        continue;
                    }
                    String emailBody = templateId.HtmlValue;
                   emailBody = emailBody.replace('{Link}', ev.Joining_Link__c != null ? ev.Joining_Link__c : '');
emailBody = emailBody.replace('{{{Recipient.Name}}}', contact.Name != null ? contact.Name : '');
emailBody = emailBody.replace('{{{Recipient.Company}}}', contact.Account != null && contact.Account.Name != null ? contact.Account.Name : '');
emailBody = emailBody.replace('{Time}', ev.StartDateTime != null ? ev.StartDateTime.format('MMM dd, yyyy HH:mm') : '');
emailBody = emailBody.replace('{{{Sender.Name}}}', sender.Name != null ? sender.Name : '');
emailBody = emailBody.replace('{{{Sender.Title}}}', sender.Title != null ? sender.Title : '');
emailBody = emailBody.replace('{{{Sender.Phone}}}', sender.Phone != null ? sender.Phone : '');
emailBody = emailBody.replace('{{{Opportunity.Category__c}}}', opp.Category__c != null ? opp.Category__c : '');
emailBody = emailBody.replace('{{{Sender.Email}}}', sender.Email != null ? sender.Email : '');
                    

                    //emailBody = emailBody.replace('{AccountName}',accountName);
                    
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    system.debug('the Emails ---->'+ contact.Email);
                    mail.setTargetObjectId(contact.Id);
                    mail.setTemplateId(templateId.Id);
                    mail.setWhatId(opp.Id); 
                    mail.setSaveAsActivity(false);
                    String subject = templateId.Subject;
subject = subject.replace('{{{Opportunity.Category__c}}}', opp.Category__c != null ? opp.Category__c : '');
mail.setSubject(subject);

                    mail.setHtmlBody(emailBody);
                    //mail.setSubject(templateId.Subject);

                    
                    emailsToSend.add(mail);
                } else {
                    System.debug('No Contact found for email: ' + opp.Contact_Email__c);
                }
            }
        }
        
        // Step 7: Send all emails
        if (!emailsToSend.isEmpty()) {
            Messaging.sendEmail(emailsToSend);
        }
    }
    
}