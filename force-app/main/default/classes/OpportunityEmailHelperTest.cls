@isTest
public class OpportunityEmailHelperTest {

    @testSetup
    static void setupTestData() {
        Contact testContact = new Contact(
            FirstName = 'Jane',
            LastName = 'Doe',
            Email = 'jane.doe@example.com'
        );
        insert testContact;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            Contact_Email__c = 'jane.doe@example.com'
        );
        insert opp;
    }

    @isTest
    static void testTriggerAfterInsertAndUpdate() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        // ✅ Case 1: INSERT with Joining_Through__c = 'Offline'
        Event ev1 = new Event(
            Subject = 'Insert Offline',
            StartDateTime = DateTime.now(),
            EndDateTime = DateTime.now().addHours(1),
            WhatId = opp.Id,
            Joining_Through__c = 'Offline'
        );

        //  Case 2: INSERT with Joining_Through__c = 'Online' (should not trigger)
        Event ev2 = new Event(
            Subject = 'Insert Online',
            StartDateTime = DateTime.now(),
            EndDateTime = DateTime.now().addHours(1),
            WhatId = opp.Id,
            Joining_Through__c = 'Online',
            Joining_Link__c = 'https://zoom.us/testmeeting' 
        );

        insert new List<Event>{ev1, ev2};

        //  Case 3: UPDATE ev2 from Online to Offline (should now trigger)
        ev2.Joining_Through__c = 'Offline';
        update ev2;

        // Optional assertions or validations
        System.assertEquals(true, Limits.getEmailInvocations() > 0, 'Expected email to be invoked at least once.');
    }
}