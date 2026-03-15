public with sharing class customapprovalprocess {
    public class Wrapper {
        @AuraEnabled public Opportunity opp { get; set; }
        @AuraEnabled public Id quoteId { get; set; }
    }

   /* @AuraEnabled(cacheable=true)
    public static Wrapper getOpportunityRecord(Id pIWorkItemId, String pageType) {
        Id quoteId;

        if (pageType == 'Request') {
            List<ProcessInstanceWorkitem> workItems = [
                SELECT ProcessInstance.TargetObjectId 
                FROM ProcessInstanceWorkitem 
                WHERE Id = :pIWorkItemId
            ];
            if (!workItems.isEmpty()) {
                quoteId = workItems[0].ProcessInstance.TargetObjectId;
            } else {
                throw new AuraHandledException('No ProcessInstanceWorkitem found.');
            }
        } else {
            List<ProcessInstanceStep> steps = [
                SELECT ProcessInstance.TargetObjectId 
                FROM ProcessInstanceStep 
                WHERE Id = :pIWorkItemId
            ];
            if (!steps.isEmpty()) {
                quoteId = steps[0].ProcessInstance.TargetObjectId;
            } else {
                throw new AuraHandledException('No ProcessInstanceStep found.');
            }
        }

        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is null from approval.');
        }

        List<Quote> quoteList = [
            SELECT Id, Name, Opportunity.Id, Opportunity.Name, Opportunity.AccountId 
            FROM Quote 
            WHERE Id = :quoteId
        ];

        if (quoteList.isEmpty()) {
            throw new AuraHandledException('No Quote found for Id: ' + quoteId);
        }

        Quote quote = quoteList[0];
        Opportunity oppRecord = quote.Opportunity;

        if (oppRecord == null) {
            throw new AuraHandledException('Quote does not have a related Opportunity.');
        }

        Wrapper response = new Wrapper();
        response.opp = oppRecord;
        response.quoteId = quote.Id;
        return response;
    }*/
    @AuraEnabled(cacheable=true)
    public static Wrapper getOpportunityRecord(Id pIWorkItemId, String pageType) {
        Id quoteId;
        
        if (pIWorkItemId == null) {
            throw new AuraHandledException('Invalid Workitem or Step Id.');
        }
        
        String idPrefix = String.valueOf(pIWorkItemId).substring(0, 3);
        
        // 04i → ProcessInstanceWorkitem
        // 04h → ProcessInstanceStep
        // 04p → ProcessInstance
        if (idPrefix == '04i') {
            // Workitem case
            List<ProcessInstanceWorkitem> workItems = [
                SELECT ProcessInstance.TargetObjectId
                FROM ProcessInstanceWorkitem
                WHERE Id = :pIWorkItemId
                LIMIT 1
            ];
            if (!workItems.isEmpty()) {
                quoteId = workItems[0].ProcessInstance.TargetObjectId;
            }
        } else if (idPrefix == '04h') {
            // Step case
            List<ProcessInstanceStep> steps = [
                SELECT ProcessInstance.TargetObjectId
                FROM ProcessInstanceStep
                WHERE Id = :pIWorkItemId
                LIMIT 1
            ];
            if (!steps.isEmpty()) {
                quoteId = steps[0].ProcessInstance.TargetObjectId;
            }
        } else if (idPrefix == '04p') {
            // ProcessInstance directly
            List<ProcessInstance> instances = [
                SELECT TargetObjectId
                FROM ProcessInstance
                WHERE Id = :pIWorkItemId
                LIMIT 1
            ];
            if (!instances.isEmpty()) {
                quoteId = instances[0].TargetObjectId;
            }
        } else {
            throw new AuraHandledException('Invalid Id type. Not a ProcessInstanceStep or Workitem.');
        }
        
        if (quoteId == null) {
            throw new AuraHandledException('No related Quote found from approval.');
        }
        
        // Fetch Quote + Opportunity details
        List<Quote> quoteList = [
            SELECT Id, Name, Opportunity.Id, Opportunity.Name, Opportunity.AccountId
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        
        if (quoteList.isEmpty()) {
            throw new AuraHandledException('No Quote found for Id: ' + quoteId);
        }
        
        Quote quote = quoteList[0];
        Opportunity oppRecord = quote.Opportunity;
        
        if (oppRecord == null) {
            throw new AuraHandledException('Quote does not have a related Opportunity.');
        }
        
        Wrapper response = new Wrapper();
        response.opp = oppRecord;
        response.quoteId = quote.Id;
        return response;
    }


    @AuraEnabled(cacheable=true)
    public static List<QuoteLineItem> getQuoteLineItems(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id cannot be null.');
        }

        return [
            SELECT Id, Product2.Name, Quantity, UnitPrice, Total_Amount__c,TotalDiscount__c,Remarks__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            ORDER BY CreatedDate ASC
        ];
    }
}