public without sharing class OpportunityPricebookHelper {

    public static void validatePricebook(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        Set<Id> changedPbIds = new Set<Id>();
        Set<Id> accIds = new Set<Id>();
        
        // Identify Opportunities where Pricebook changed
        for (Opportunity opp : newList) {
            Opportunity oldOpp = oldMap.get(opp.Id);
            if (opp.Pricebook2Id != oldOpp.Pricebook2Id && opp.Pricebook2Id != null) {
                changedPbIds.add(opp.Pricebook2Id);
                if (opp.AccountId != null) accIds.add(opp.AccountId);
            }
        }
        
        if (changedPbIds.isEmpty()) return;

        // Query Pricebooks
        Map<Id, Pricebook2> pbMap = new Map<Id, Pricebook2>(
            [SELECT Id, Name, IsStandard, Customer__c,
                    Supply_Location_Plant__c,
                    Customer_Location_Shipping_Location__c,Validity_Date__c
             FROM Pricebook2
             WHERE Id IN :changedPbIds AND IsActive = true]
        );

        // Query Accounts for location info
        Map<Id, Account> accMap = new Map<Id, Account>(
            [SELECT Id, Shipping_Address_readonly__City__s, BillingCity FROM Account WHERE Id IN :accIds]
        );

        // Validate each changed Opportunity
        for (Opportunity opp : newList) {
            Opportunity oldOpp = oldMap.get(opp.Id);
            if (opp.Pricebook2Id == oldOpp.Pricebook2Id || opp.Pricebook2Id == null) continue;

            Pricebook2 pb = pbMap.get(opp.Pricebook2Id);
            if (pb == null) continue;
            if (pb.IsStandard) continue; // Always allow standard pricebook

            Account acc = accMap.get(opp.AccountId);
            
            Boolean isValid = true;
            List<String> failReasons = new List<String>();

            // ---- Validity Date Check ----
            if (pb.Validity_Date__c == null || pb.Validity_Date__c < Date.today()) {
                system.debug('Validity_Date__c-->'+pb.Validity_Date__c +'todays date-->'+Date.today());
                isValid = false;
                failReasons.add('Pricebook validity date is missing or has expired');
            }


            //--- Prepare comparison values ---
            String oppCustomer = opp.AccountId;
            List<String> oppPlants = (opp.Plant_and_Shipping_Point__c != null) ? opp.Plant_and_Shipping_Point__c.split(';'): new List<String>();
               
                
            String oppLocation = (acc != null && acc.Shipping_Address_readonly__City__s != null)
                ? acc.Shipping_Address_readonly__City__s.trim(): (acc != null && acc.BillingCity != null ? acc.BillingCity.trim() : null);
                

          

            // ---- Customer Check ----
            if (pb.Customer__c != null && pb.Customer__c != oppCustomer) {
                isValid = false;
                failReasons.add('Customer mismatch');
            }

            // ---- Plant Check (case-insensitive) ----
            if (pb.Supply_Location_Plant__c != null) {
                List<String> pbPlants = new List<String>();
                for (String pl : pb.Supply_Location_Plant__c.split(';')) {
                    pbPlants.add(pl.trim().toLowerCase());
                }

                Boolean plantMatched = false;
                for (String pl : oppPlants) {
                    if (pbPlants.contains(pl.trim().toLowerCase())) {
                        plantMatched = true;
                        break;
                    }
                }

                if (!plantMatched) {
                    isValid = false;
                    failReasons.add('Plant mismatch');
                }
            }

            // ---- Location Check (case-insensitive) ----
            if (pb.Customer_Location_Shipping_Location__c != null && oppLocation != null) {
                List<String> pbLocs = new List<String>();
                for (String loc : pb.Customer_Location_Shipping_Location__c.split(';')) {
                    pbLocs.add(loc.trim().toLowerCase());
                }

                if (!pbLocs.contains(oppLocation.trim().toLowerCase())) {
                    isValid = false;
                    failReasons.add('Location mismatch');
                }
            } else if (pb.Customer_Location_Shipping_Location__c != null && oppLocation == null) {
                isValid = false;
                failReasons.add('Opportunity has no location to match');
            }

            // ---- Final Validation ----
            if (!isValid) {
                opp.addError('Pricebook "' + pb.Name + '" cannot be used for this Opportunity. '
                    + 'Reason(s): ' + String.join(failReasons, ', ') + '.');
            }
        }
    }
    
    
   public static void validatePricebookValidity(List<Opportunity> oppList) {
    // Collect Pricebook IDs from Opportunities
    Set<Id> pricebookIds = new Set<Id>();
    for (Opportunity opp : oppList) {
        // Skip if Closed Won or no Pricebook assigned
        if (opp.Pricebook2Id != null && opp.StageName != 'Closed Won') {
            pricebookIds.add(opp.Pricebook2Id);
        }
    }

    if (pricebookIds.isEmpty()) return;

    // Query relevant Pricebooks
    Map<Id, Pricebook2> pbMap = new Map<Id, Pricebook2>(
        [SELECT Id, Name, Validity_Date__c 
         FROM Pricebook2 
         WHERE Id IN :pricebookIds]
    );

    // Validate Opportunities
    for (Opportunity opp : oppList) {
        if (opp.StageName == 'Closed Won' || opp.Pricebook2Id == null) continue;

        Pricebook2 pb = pbMap.get(opp.Pricebook2Id);

        if (pb != null && (pb.Validity_Date__c == null || pb.Validity_Date__c < Date.today())) {
            opp.addError(
                'The selected Pricebook "' + pb.Name + 
                '" has expired or has no validity date. Please choose a valid Pricebook.'
            );
        }
    }
}


}