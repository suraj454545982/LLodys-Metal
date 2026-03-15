@isTest
public class SurveryControllerTest {

    @isTest
    public static void testGetSurveyByUniqueId() {
    	// Step 1: Create a test Account
        Account testAccount = new Account(
            Name = 'Test Account',
            Category__c = 'Steel',
            Industry__c = 'Trader',
            Company_Email_ID__c = 'testaccount@gmail.com',
            Phone = '7894561230'
        );
        insert testAccount;

        // Step 1: Create test data
        Survey__c testSurvey = new Survey__c(
         
            Status__c = 'Sent',
            Name = 'Test Survey',
            Email_Id__c = 'test@example.com',
            Phone__c = '1234567890',
            ClientDurationOptions__c = '1-3 years',
            Account_Name__c = 'Test Account',
            Primary_Product__c = 'Iron Ore Pellet',
            Role__c = 'Project Lead',
            Company_Type__c = 'Mining Company'
           
        );
        insert testSurvey;
		survey__c newsu = [ select id,Unique_ID__c from survey__c where role__c = 'Project Lead'];
        Test.startTest();
        // Step 2: Call the method
        Survey__c result = SurveyController.getSurveyByUniqueId(newsu.Unique_ID__c);
        Test.stopTest();

        // Step 3: Assert the result
        System.assertNotEquals(null, result, 'Survey should not be null');
    }
        
   	@isTest
    public static void testUpdateSurveyWithExampleData() {
        // Step 1: Create a test Survey__c record with example data
        Survey__c survey = new Survey__c(
            Status__c = 'Sent',
            Name = 'Survey Name',
            Email_Id__c = 'testsurvey@cloudodyssey.co',
            Phone__c = '08110030220',
            Account_Name__c = 'SS Steels new',
            Primary_Product__c = 'Steel'
        );
        insert survey;

        // Step 2: Prepare respondentInfo map
        Map<String, String> respondentInfo = new Map<String, String>{
            'name' => 'Survey Name',
            'email' => 'testsurvey@cloudodyssey.co',
            'phone' => '08110030220',
            'companyName' => 'SS Steels new',
            'products' => 'Steel',
            'role' => 'Procurement Manager',
            'companyType' => 'Mining Company',
            'clientDuration' => '1-3 years'
        };

        // Step 3: Prepare surveyResponses map (example values)
        Map<String, String> surveyResponses = new Map<String, String>{
            'q1' => '4 - Agree',
            'q2' => '5 - Strongly Agree',
            'q3' => '4 - Agree',
            'q4' => '3 - Neutral',
            'q5' => '4 - Agree',
            'q6' => '4 - Agree',
            'q7' => '3 - Neutral',
            'q8' => '5 - Strongly Agree',
            'q9' => '4 - Agree',
            'q10' => '4 - Agree',
            'q11' => '3 - Neutral',
            'q12' => '4 - Agree',
            'q13' => '3 - Neutral',
            'q14' => '3 - Neutral'
        };

        // Step 4: Call the method
        Test.startTest();
        SurveyController.updateSurvey(survey.Id, surveyResponses, respondentInfo);
        Test.stopTest();

        // Step 5: Query and assert
        Survey__c updatedSurvey = [SELECT Name, Email_Id__c, Phone__c, Account_Name__c, Primary_Product__c,
                                          Role__c, Company_Type__c, ClientDurationOptions__c, Status__c
                                   FROM Survey__c
                                   WHERE Id = :survey.Id];

        System.assertEquals('Survey Name', updatedSurvey.Name);
        System.assertEquals('testsurvey@cloudodyssey.co', updatedSurvey.Email_Id__c);
        System.assertEquals('08110030220', updatedSurvey.Phone__c);
        System.assertEquals('SS Steels new', updatedSurvey.Account_Name__c);
        System.assertEquals('Steel', updatedSurvey.Primary_Product__c);
        System.assertEquals('Procurement Manager', updatedSurvey.Role__c);
        System.assertEquals('Mining Company', updatedSurvey.Company_Type__c);
        System.assertEquals('1-3 years', updatedSurvey.ClientDurationOptions__c);
        System.assertEquals('Submitted', updatedSurvey.Status__c);
    }

}