@isTest
public class SurveyServiceTest {
    
	
    @testSetup
    static void setupTestData() {
        // Create test Survey__c records
        List<Survey__c> surveys = new List<Survey__c>{
            new Survey__c(
                Unique_ID__c = 'ABC123',
                Email_Id__c = 'test1@example.com',
                Account_Name__c = 'Test Account 1'
            ),
            new Survey__c(
                Unique_ID__c = 'XYZ789',
                Email_Id__c = 'test2@example.com',
                Account_Name__c = 'Test Account 2'
            )
        };
        insert surveys;
    }

    
    //Positive
    @isTest
    static void testUpdateSurveyUrlsWithCommunityBase_Positive() {
        // Arrange
        List<Survey__c> surveys = [SELECT Id FROM Survey__c];
        List<Id> surveyIds = new List<Id>();
        for (Survey__c s : surveys) {
            surveyIds.add(s.Id);
        }

        Test.startTest();
        SurveyService.updateSurveyUrlsWithCommunityBase(surveyIds);
        Test.stopTest();

        // Assert
        List<Survey__c> updatedSurveys = [SELECT URL__c, Status__c FROM Survey__c WHERE Id IN :surveyIds];
        for (Survey__c s : updatedSurveys) {
            System.assertNotEquals(null, s.URL__c, 'URL__c should be populated');
            System.assertEquals('Sent', s.Status__c, 'Status__c should be "Sent"');
        }
    }
    
    //Negative
    @isTest
    static void testUpdateSurveyUrlsWithCommunityBase_Negative_NullList() {
        // Act
        Test.startTest();
        SurveyService.updateSurveyUrlsWithCommunityBase(null);
        Test.stopTest();

        // Assert: No exception should be thrown
        System.assert(true, 'Method should handle null input gracefully');
    }




}