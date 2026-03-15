@isTest
public class LeadCheckInControllerTest {
    @isTest
    static void testUpdateLeadLocation() {
        // Create a test Lead record
        Lead testLead = new Lead(
            LastName = 'TestLead',
            Company = 'TestCompany'
        );
        
        insert testLead;
        
        // Define test latitude and longitude values
        Decimal testLatitude = 12.345678;
        Decimal testLongitude = 98.765432;
        
        // Call the method to update the lead location
        Test.startTest();
        LeadCheckInController.updateLocation(testLead.Id, testLatitude, testLongitude);
        Test.stopTest();
        
        // Query the lead again to verify the update
        Lead updatedLead = [SELECT Location__Latitude__s, Location__Longitude__s FROM Lead WHERE Id = :testLead.Id];
        
        // Assert that the values were updated correctly
        System.assertEquals(testLatitude, updatedLead.Location__Latitude__s, 'Latitude should be updated');
        System.assertEquals(testLongitude, updatedLead.Location__Longitude__s, 'Longitude should be updated');
    }
}