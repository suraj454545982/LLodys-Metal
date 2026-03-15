@IsTest
public class EmailtestTest {

    @IsTest
    static void testSendOfflineJoiningEmails() {
        // Create a test user to use for runAs
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'testusr',
            Email = 'testuser89@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'testuser' + DateTime.now().getTime() + '@example.com'
        );
        insert testUser;

        // Separate setup DML using runAs block
        System.runAs(testUser) {
            // Insert Email Templates
            List<EmailTemplate> templates = new List<EmailTemplate>{
                new EmailTemplate(
                    Name = 'Plant Visit Template',
                    DeveloperName = 'Plant_visit_Mail_1748250621418',
                    HtmlValue = 'Dear {{{Recipient.Name}}}, welcome to {{{Recipient.Company}}}. Here is your link: {Link} at {Time}. Regards, {{{Sender.Name}}}, {{{Sender.Title}}}, {{{Sender.Phone}}}, {{{Sender.Email}}}, {{{Opportunity.Category__c}}}',
                    TemplateType = 'custom',
                    Subject = 'Test Subject',
                    FolderId = UserInfo.getUserId()
                ),
                new EmailTemplate(
                    Name = 'Online Meeting Template',
                    DeveloperName = 'Online_meeting_mail_1749186607452',
                    HtmlValue = 'Dear {{{Recipient.Name}}}, your online meeting is scheduled at {Time}. Link: {Link}. Regards, {{{Sender.Name}}}',
                    TemplateType = 'custom',
                    Subject = 'Test Subject',
                    FolderId = UserInfo.getUserId()
                )
            };
            insert templates;
        }

        // Now continue with regular data (non-setup DML)
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Contact testContact = new Contact(
            LastName = 'Test',
            Email = 'testuser89@example.com',
            AccountId = testAccount.Id
        );
        insert testContact;

        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            Contact_Email__c = testContact.Email
            //Category__c = 'Product Demo'
        );
        insert testOpp;

        Event testEvent = new Event(
            WhatId = testOpp.Id,
            Subject = 'Test Event',
            StartDateTime = System.now().addDays(1),
            EndDateTime = System.now().addDays(1).addHours(1),
            Joining_Link__c = 'https://joinlink.com',
            Joining_through__c = 'Online'
        );
        insert testEvent;

        // Run the method under test
        Test.startTest();
        Emailtest.sendOfflineJoiningEmails(new List<Event>{testEvent});
        Test.stopTest();

        System.assert(true, 'No exceptions thrown');
    }
}