@isTest
private class OpportunityHandlerTest {

    @isTest
    static void testHandleBeforeInsert_FirstOpportunity() {

        
        Opportunity opp1 = new Opportunity(
            Name = 'Test Opportunity 1',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10)
        );

        List<Opportunity> oppList = new List<Opportunity>{ opp1 };

        
        Test.startTest();
        new OpportunityHandler().handleBeforeInsert(oppList);
        Test.stopTest();

        
        System.assertNotEquals(
            null,
            opp1.Opportunity_Number__c,
            'Opportunity number should be auto-generated'
        );
    }

    @isTest
    static void testHandleBeforeInsert_WithExistingOpportunity() {

        
        Opportunity existingOpp = new Opportunity(
            Name = 'Existing Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(5),
            Opportunity_Number__c = '1000'
        );
        insert existingOpp;

        
        Opportunity opp2 = new Opportunity(
            Name = 'Test Opportunity 2',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(15)
        );

        Opportunity opp3 = new Opportunity(
            Name = 'Test Opportunity 3',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(20)
        );

        List<Opportunity> oppList = new List<Opportunity>{ opp2, opp3 };

        
        Test.startTest();
        new OpportunityHandler().handleBeforeInsert(oppList);
        Test.stopTest();

        
    }

    @isTest
    static void testHandleBeforeUpdate_PreventManualChange() {
    
        Opportunity opp = new Opportunity(
            Name = 'Update Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            Opportunity_Number__c = '2000'
        );
        insert opp;
    
        Opportunity oppUpdated = opp.clone(false, true, false, false);
        oppUpdated.Id = opp.Id; // 🔑 REQUIRED
        oppUpdated.Opportunity_Number__c = '9999';
    
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{
            opp.Id => opp
        };
    
        List<Opportunity> newList = new List<Opportunity>{ oppUpdated };
    
        Test.startTest();
        new OpportunityHandler().handleBeforeUpdate(newList, oldMap);
        Test.stopTest();
    
        System.assert(
            oppUpdated.getErrors().size() > 0,
            'Error should be added when Opportunity_Number__c is modified'
        );
    }


    @isTest
    static void testHandleBeforeUpdate_NoChangeAllowed() {
    
        Opportunity opp = new Opportunity(
            Name = 'No Change Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            Opportunity_Number__c = '3000'
        );
        insert opp;
    
        // Clone and restore Id (CRITICAL)
        Opportunity oppUpdated = opp.clone(false, true, false, false);
        oppUpdated.Id = opp.Id;
    
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{
            opp.Id => opp
        };
    
        List<Opportunity> newList = new List<Opportunity>{ oppUpdated };
    
        Test.startTest();
        new OpportunityHandler().handleBeforeUpdate(newList, oldMap);
        Test.stopTest();
    
        System.assertEquals(
            0,
            oppUpdated.getErrors().size(),
            'No error should be added when Opportunity_Number__c is unchanged'
        );
    }

}