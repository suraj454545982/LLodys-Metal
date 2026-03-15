public class OpportunityHandler {
    
      /**
* @description Handles before insert operations for Opportunity records
* @param newQuotes List of new Opportunity records
*/
    public void handleBeforeInsert(List<Opportunity> newOpps) {
        if (newOpps == null || newOpps.isEmpty()) return;
        
        // Start from a default base number
        Long nextNumber = Long.valueof(System.Label.OpportunityStartNUmber);
        
        // Get the last used opportunity number (as a number, ordering numerically)
        list<Opportunity> lastOpp = [SELECT Opportunity_Number__c 
                                     FROM Opportunity 
                                     WHERE Opportunity_Number__c != null
                                     ORDER BY Opportunity_Number__c DESC 
                                     LIMIT 1];
        
        if (lastOpp.size()>0 && String.isNotBlank(lastOpp[0].Opportunity_Number__c))
        {
            nextNumber = Long.valueOf(lastOpp[0].Opportunity_Number__c) + 1;
        }
        
        // Assign new unique numbers to the inserted opportunities
        for (Opportunity opp : newOpps) {
            if (String.isBlank(opp.Opportunity_Number__c)) {
                opp.Opportunity_Number__c = String.valueOf(nextNumber);
                nextNumber++;
            }
        }
    }
    
    // Prevent manual modification of Opportunity_Number__c
    public void handleBeforeUpdate(List<Opportunity> newOpps, Map<Id, Opportunity> oldOppMap) {
        for (Opportunity opp : newOpps) {
            Opportunity oldOpp = oldOppMap.get(opp.Id);
            if (opp.Opportunity_Number__c != oldOpp.Opportunity_Number__c) {
                opp.addError('Opportunity Number cannot be modified.');
            }
        }
    }
    
    
   
}