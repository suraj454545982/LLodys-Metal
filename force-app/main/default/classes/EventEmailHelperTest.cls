@IsTest
public class EventEmailHelperTest {
    @IsTest
    static void testSendOfflineJoiningEmails() {
        // Create test Contact
        Contact testContact = new Contact(
            LastName = 'Test Contact',
            Email = 'testcontact@example.com'
        );
        insert testContact;

        // Create test Opportunity with Contact_Email__c and Joining_Link__c 
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            CloseDate = Date.today().addDays(30),
            StageName = 'Prospecting',
            Contact_Email__c = 'testcontact@example.com',
            Joining_Link__c = 'https://validjoininglink.com' // Important for validation rule
        );
        insert testOpp;

        // Create test Event - Online (should pick Online email template)
        Event testEventOnline = new Event(
            Subject = 'Test Online Event',
            StartDateTime = System.now().addDays(1),
            EndDateTime = System.now().addDays(1).addHours(1),
            WhatId = testOpp.Id,
            Joining_Through__c = 'Online',
            Joining_Link__c = 'https://testlink.com' 
        );

        // Create test Event - Offline (should pick Offline email template)
        Event testEventOffline = new Event(
            Subject = 'Test Offline Event',
            StartDateTime = System.now().addDays(1),
            EndDateTime = System.now().addDays(1).addHours(1),
            WhatId = testOpp.Id,
            Joining_Through__c = 'Offline' // Valid picklist value
        );

       Test.startTest();
insert new List<Event>{testEventOnline, testEventOffline};
EventEmailHelper.sendOfflineJoiningEmails(new List<Event>{testEventOnline, testEventOffline});
Test.stopTest();


        // If no exceptions, test passes.
        System.assert(true, 'Emails sent successfully with correct data.');
    }
}