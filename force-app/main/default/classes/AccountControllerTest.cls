@isTest
public class AccountControllerTest {

    //Positive
    @isTest
    public static void testGetAccounts_Positive() {
        // Step 1: Create test data
        List<Account> testAccounts = new List<Account>{
            new Account(Name = 'Test Account 1', Category__c = 'Iron Ore', Company_Email_ID__c = 'test1@example.com', Phone = '1234567890'),
            new Account(Name = 'Test Account 2', Category__c = 'Steel', Company_Email_ID__c = 'test2@example.com', Phone = '0987654321')
        };
        insert testAccounts;

        // Step 2: Call the method
        Test.startTest();
        List<Account> result = AccountController.getAccounts();
        Test.stopTest();

        // Step 3: Assert the results
        System.assertNotEquals(0, result.size(), 'The result should not be empty');
        System.assertEquals(2, result.size(), 'There should be 2 accounts returned');
    }
    
    //Negative
	@isTest
	public static void testGetAccounts_Negative() {
	// No data inserted
		Test.startTest();
		List<Account> result = AccountController.getAccounts();
		Test.stopTest();

		System.assertEquals(0, result.size(), 'Expected empty result when no accounts exist');
	}
    
	// Positive Test Case: Valid Account IDs
	@isTest
	static void testCreateSurveyRecords_Positive() {
		// Arrange: Create test accounts
		List<Account> testAccounts = new List<Account>{
            	new Account(Name = 'Test Acc 1', Company_Email_ID__c = 'test1@example.com', Phone = '1234567890', Category__c = 'Steel'),
                new Account(Name = 'Test Acc 2', Company_Email_ID__c = 'test2@example.com', Phone = '0987654321', Category__c = 'Iron Ore')
		};
		insert testAccounts;

		List<String> accountIds = new List<String>();
		for (Account acc : testAccounts) {
			accountIds.add(acc.Id);
		}

        Test.startTest();
		AccountController.createSurveyRecords(accountIds,true);
        AccountController.updateAccounts(testAccounts);
		Test.stopTest();

		// Assert: Check if Survey__c records were created
		List<Survey__c> surveys = [SELECT Id, Account__c FROM Survey__c WHERE Account__c IN :accountIds];
		System.assertEquals(2, surveys.size(), 'Expected 2 survey records to be created');
	}
    
    
	// Negative Test Case: Empty Account ID list
	@isTest
	static void testCreateSurveyRecords_Negative() {
		// Arrange: Empty list
		List<String> emptyList = new List<String>();

		//Assert: Should not throw an exception, but also not insert anything
		Test.startTest();
		AccountController.createSurveyRecords(emptyList,true);
		Test.stopTest();
		
        List<Survey__c> surveys = [SELECT Id FROM Survey__c];
		System.assertEquals(0, surveys.size(), 'No survey records should be created for empty input');
	}

   


    
}