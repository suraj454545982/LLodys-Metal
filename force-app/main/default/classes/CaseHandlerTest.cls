@isTest
public class CaseHandlerTest {
  
    @isTest
    static void testBeforeInsertHandler_WithExistingCases() {
        // Create a test contact (recipient for Flow email)
        Contact con = new Contact(FirstName = 'Test', LastName = 'User', Email = 'testuser@example.com',Phone='9876543210');
        insert con;
        Id RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Service Request').getRecordTypeId();
        
        // Existing case to simulate last case number
        Case existingCase = new Case(
            Subject = 'Existing Case',
            Origin = 'Phone',
            ContactId = con.Id,
            category__c = 'DRI'
        );
        insert existingCase;
        existingCase.category__c = 'DRI';
        update existingCase;
        // New cases
        List<Case> newCases = new List<Case>{
            new Case(Subject = 'New Case 1', Origin = 'Phone', ContactId = con.Id),
                new Case(Subject = 'New Case 2', Origin = 'Phone', ContactId = con.Id)
                };
                    
                    // Call handler
                    Test.startTest();
        CaseHandler.beforeInsertHandler(newCases);
        Test.stopTest();
        
        
    }
    
    @isTest
    static void testBeforeInsertHandler_WithoutExistingCases() {
        // Create a test contact
        Contact con = new Contact(FirstName = 'Test', LastName = 'User', Email = 'testuser@example.com',Phone='9876543210');
        insert con;
        Id RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Service Request').getRecordTypeId();
        
        Case existingCase = new Case(
            Subject = 'Existing Case',
            Origin = 'Email',
            ContactId = con.Id,
            recordtypeid = RecordTypeId
        );
        insert existingCase;
        // New cases
        List<Case> newCases = new List<Case>{
            new Case(Subject = 'Case A', Origin = 'Email', ContactId = con.Id),
                new Case(Subject = 'Case B', Origin = 'Web', ContactId = con.Id)
                };
                    
                    // Call handler
                    Test.startTest();
        CaseHandler.beforeInsertHandler(newCases);
        Test.stopTest();
        
        // Verify
        Long labelVal = Long.valueOf(Label.Case_Number_Label);
        
    }

}