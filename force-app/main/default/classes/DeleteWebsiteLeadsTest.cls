@isTest
private class DeleteWebsiteLeadsTest {

    @isTest
    static void testDeleteWebsiteLeads() {

        // -----------------------------
        // Create test Leads
        // -----------------------------
        Lead l1 = new Lead(
            LastName = 'Lead One',
            Company = 'Test Company',
            Status = 'Open',
            Email = 'lead1@test.com'
        );

        Lead l2 = new Lead(
            LastName = 'Lead Two',
            Company = 'Test Company',
            Status = 'Open',
            Email = 'lead2@test.com'
        );

        insert new List<Lead>{ l1, l2 };

        List<Id> leadIds = new List<Id>{ l1.Id, l2.Id };

        // -----------------------------
        // Execute Queueable
        // -----------------------------
        Test.startTest();
        System.enqueueJob(new DeleteWebsiteLeads(leadIds));
        Test.stopTest();

        // -----------------------------
        // Verify Leads are deleted
        // -----------------------------
        List<Lead> deletedLeads = [
            SELECT Id, IsDeleted
            FROM Lead
            WHERE Id IN :leadIds
            ALL ROWS
        ];

        System.assertEquals(2, deletedLeads.size(),
            'Both leads should be found in recycle bin');

        for (Lead l : deletedLeads) {
            System.assertEquals(true, l.IsDeleted,
                'Lead should be deleted');
        }
    }

    @isTest
    static void testDeleteWebsiteLeadsWithEmptyList() {

        // -----------------------------
        // Execute Queueable with empty list
        // -----------------------------
        Test.startTest();
        System.enqueueJob(new DeleteWebsiteLeads(new List<Id>()));
        Test.stopTest();

        // No exception = pass
        System.assert(true, 'Queueable handled empty list safely');
    }

    @isTest
    static void testDeleteWebsiteLeadsWithNullList() {

        // -----------------------------
        // Execute Queueable with null list
        // -----------------------------
        Test.startTest();
        System.enqueueJob(new DeleteWebsiteLeads(null));
        Test.stopTest();

        // No exception = pass
        System.assert(true, 'Queueable handled null list safely');
    }
}