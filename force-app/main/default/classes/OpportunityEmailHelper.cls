public class OpportunityEmailHelper {
    public static void sendOfflineJoiningEmails(List<Event> eventList) {
        Set<Id> whatIds = new Set<Id>();

        // Collect Opportunity Ids from Events
        for (Event e : eventList) {
            if (e.WhatId != null && e.WhatId.getSObjectType() == Opportunity.SObjectType) {
                whatIds.add(e.WhatId);
            }
        }

        if (whatIds.isEmpty()) {
            return; // no opportunities found, exit early
        }

        // Get organization name (Sender Company)
        Organization org = [SELECT Name FROM Organization LIMIT 1];
        String senderCompany = org.Name;

        // Query Opportunities with required fields including Account Name
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(
            [SELECT Id, Name, Contact_Email__c, Category__c, Account.Name
             FROM Opportunity WHERE Id IN :whatIds]
        );

        // Collect emails to query Contacts
        Set<String> emails = new Set<String>();
        for (Opportunity opp : oppMap.values()) {
            if (String.isNotBlank(opp.Contact_Email__c)) {
                emails.add(opp.Contact_Email__c.toLowerCase());
            }
        }

        // Query Contacts by email
        Map<String, Contact> emailToContactMap = new Map<String, Contact>();
        if (!emails.isEmpty()) {
            List<Contact> contacts = [SELECT Id, FirstName, LastName, Email FROM Contact WHERE Email IN :emails];
            for (Contact c : contacts) {
                emailToContactMap.put(c.Email.toLowerCase(), c);
            }
        }

        // Get email template content (HTML + subject)
        EmailTemplate template = [
            SELECT HtmlValue, Subject 
            FROM EmailTemplate 
            WHERE DeveloperName = 'Plant_visit_Mail_1748250621418' 
            LIMIT 1
        ];

        // Get sender details
        User currentUser = [
            SELECT FirstName, LastName, Title, Phone, Email 
            FROM User 
            WHERE Id = :UserInfo.getUserId()
        ];

        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        // Compose and send email
        for (Event ev : eventList) {
            Opportunity opp = oppMap.get(ev.WhatId);
            if (opp != null && String.isNotBlank(opp.Contact_Email__c)) {
                Contact contact = emailToContactMap.get(opp.Contact_Email__c.toLowerCase());
                if (contact == null) continue;

                // Determine if joining is online or offline (adjust field API name as needed)
                Boolean isOnline = (ev.Joining_through__c != null && ev.Joining_through__c.toLowerCase() == 'online');

                // Prepare email content
                String htmlBody = template.HtmlValue;
                String subject = template.Subject;

                // Replace placeholders
                htmlBody = htmlBody
                    .replace('{{{Recipient.FirstName}}}', contact.FirstName != null ? contact.FirstName : '')
                    .replace('{{{Recipient.LastName}}}', contact.LastName != null ? contact.LastName : '')
                    .replace('{{{Recipient.Category__c}}}', opp.Category__c != null ? opp.Category__c : '')
                    .replace('{{{Recipient.Company}}}', opp.Account != null && opp.Account.Name != null ? opp.Account.Name : '')
                    .replace('{{{Sender.LastName}}}', currentUser.LastName)
                    .replace('{{{Sender.Title}}}', currentUser.Title != null ? currentUser.Title : '')
                    .replace('{{{Sender.Phone}}}', currentUser.Phone != null ? currentUser.Phone : '')
                    .replace('{{{Sender.Email}}}', currentUser.Email)
                    .replace('{{{Organization.Name}}}', senderCompany)
                    .replace('[LMEL sales person Name]', currentUser.FirstName + ' ' + currentUser.LastName)
                    // Conditionally add joining link or empty string
                   // .replace('[Joining Link]', isOnline ? (ev.Joining_Link__c != null ? ev.Joining_Link__c : 'https://your-default-online-link.com') : '');
						.replace('[Joining Link]',isOnline ? (ev.Joining_Link__c != null
            ? '<a href="' + ev.Joining_Link__c + '" target="_blank" style="color:#1a73e8;text-decoration:underline;">' + ev.Joining_Link__c + '</a>'
            : '<a href="https://your-default-online-link.com" target="_blank" style="color:#1a73e8;text-decoration:underline;">https://your-default-online-link.com</a>'): '');
                
                    subject = subject
                    .replace('LMEL Company Name', senderCompany);

                // Prepare email
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{opp.Contact_Email__c});
                mail.setSubject(subject);
                mail.setHtmlBody(htmlBody);
                mail.setSaveAsActivity(false);

                emailsToSend.add(mail);
            }
        }

        if (!emailsToSend.isEmpty()) {
            Messaging.sendEmail(emailsToSend);
        }
    }
}







/*public class OpportunityEmailHelper {

    public static void sendOfflineJoiningEmails(List<Event> eventList) {
        Set<Id> whatIds = new Set<Id>();

        // Collect Opportunity Ids from Events
        for (Event e : eventList) {
            if (e.WhatId != null && e.WhatId.getSObjectType() == Opportunity.SObjectType) {
                whatIds.add(e.WhatId);
            }
        }

        // Query Opportunities with Contact_Email__c
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(
            [SELECT Id, Contact_Email__c FROM Opportunity WHERE Id IN :whatIds]
        );

        // Collect emails to query Contacts
        Set<String> emails = new Set<String>();
        for (Opportunity opp : oppMap.values()) {
            if (String.isNotBlank(opp.Contact_Email__c)) {
                emails.add(opp.Contact_Email__c.toLowerCase());
            }
        }

        // Query Contacts by email
        Map<String, Contact> emailToContactMap = new Map<String, Contact>();
        if (!emails.isEmpty()) {
            List<Contact> contacts = [SELECT Id, Email FROM Contact WHERE Email IN :emails];
            for (Contact c : contacts) {
                emailToContactMap.put(c.Email.toLowerCase(), c);
            }
        }

        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        // Get your Lightning email template Id by DeveloperName
        Id emailTemplateId = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Plant_visit_Mail_1748250621418' LIMIT 1].Id;

        // Prepare emails
        for (Event ev : eventList) {
            Opportunity opp = oppMap.get(ev.WhatId);
            if (opp != null && String.isNotBlank(opp.Contact_Email__c)) {
                Contact contact = emailToContactMap.get(opp.Contact_Email__c.toLowerCase());
                if (contact != null) {
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setTargetObjectId(contact.Id);       
                    mail.setTemplateId(emailTemplateId);
                    mail.setWhatId(opp.Id);
                    mail.setSaveAsActivity(false);
                    emailsToSend.add(mail);
                } else {
                    System.debug('No Contact found for email: ' + opp.Contact_Email__c);
                }
            }
        }

        if (!emailsToSend.isEmpty()) {
            Messaging.sendEmail(emailsToSend);
        }
    }
}*/