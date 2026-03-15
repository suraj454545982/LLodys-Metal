@isTest
public class TestOpportunityHandler {
    // Test setup method to create necessary data
    @TestSetup
   Public static void setup() {
        // Create a test opportunity with a known number
        Opportunity opp = new Opportunity(
            Name = 'TestClaass',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            Opportunity_Number__c = '1000'
        );
            insert opp;
       Opp.Quantity__c = 2;
       update opp;
       
    }
    
    @isTest
    static void testHandleBeforeInsert() {
        // Verify setup data
        List<Opportunity> setupOpps = [SELECT Id, Opportunity_Number__c FROM Opportunity WHERE Opportunity_Number__c = '1000'];
        System.assertEquals(1, setupOpps.size(), 'Setup opportunity should exist');
        
        // Test data
        List<Opportunity> newOpps = new List<Opportunity>();
        newOpps.add(new Opportunity(
            Name = 'Test Opp 1',
            StageName = 'Prospecting',
            CloseDate = Date.today()
        ));
        newOpps.add(new Opportunity(
            Name = 'Test Opp 2',
            StageName = 'Prospecting',
            CloseDate = Date.today()
        ));
        
        // Test
        Test.startTest();
        OpportunityHandler handler = new OpportunityHandler();
        handler.handleBeforeInsert(newOpps);
        Test.stopTest();
        
        // Verify
        System.assertEquals('1001', newOpps[0].Opportunity_Number__c, 'First opportunity should have number 1001');
        System.assertEquals('1002', newOpps[1].Opportunity_Number__c, 'Second opportunity should have number 1002');
    }
    
    @isTest
    static void testHandleBeforeInsertWithEmptyList() {
        // Test with empty list
        List<Opportunity> newOpps = new List<Opportunity>();
        
        Test.startTest();
        OpportunityHandler handler = new OpportunityHandler();
        handler.handleBeforeInsert(newOpps);
        Test.stopTest();
        
        // Verify no errors and empty list remains empty
        System.assertEquals(0, newOpps.size(), 'Empty list should remain empty');
    }
    
    @isTest
    static void testHandleBeforeInsertWithNull() {
        // Test with null list
        List<Opportunity> newOpps = null;
        
        Test.startTest();
        OpportunityHandler handler = new OpportunityHandler();
        handler.handleBeforeInsert(newOpps);
        Test.stopTest();
        
        // Verify no errors
        System.assert(true, 'Null list should be handled without errors');
    }
    
    @isTest
    static void testHandleBeforeUpdatePreventNumberChange() {
        // Get existing opportunity
        Opportunity opp = [SELECT Id, Opportunity_Number__c FROM Opportunity WHERE  Opportunity_Number__c = '1000' LIMIT 1];
        Map<Id, Opportunity> oldOppMap = new Map<Id, Opportunity>{opp.Id => opp.clone(true)};
            
            // Modify opportunity number
            opp.Opportunity_Number__c = '2000';
        List<Opportunity> newOpps = new List<Opportunity>{opp};
            
            // Test
            Test.startTest();
        OpportunityHandler handler = new OpportunityHandler();
        handler.handleBeforeUpdate(newOpps, oldOppMap);
        Test.stopTest();
        
        // Verify error was added
        System.assert(opp.hasErrors(), 'Opportunity should have an error');
        System.assertEquals('Opportunity Number cannot be modified.', 
                            opp.getErrors()[0].getMessage(), 
                            'Correct error message should be set');
    }
    
    @isTest
    static void testHandleBeforeUpdateNoNumberChange() {
        // Get existing opportunity
        Opportunity opp = [SELECT Id, Opportunity_Number__c FROM Opportunity WHERE Opportunity_Number__c = '1000' LIMIT 1];
        Map<Id, Opportunity> oldOppMap = new Map<Id, Opportunity>{opp.Id => opp.clone(true)};
            
            // Modify non-number field
            opp.Name = 'Updated Test Opp';
        List<Opportunity> newOpps = new List<Opportunity>{opp};
            
            // Test
            Test.startTest();
        OpportunityHandler handler = new OpportunityHandler();
        handler.handleBeforeUpdate(newOpps, oldOppMap);
        Test.stopTest();
        
        // Verify no errors
        System.assert(!opp.hasErrors(), 'Opportunity should not have errors');
    }
}