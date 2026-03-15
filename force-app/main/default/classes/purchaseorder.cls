public without sharing class purchaseorder {
    public class Wrapper {
        @AuraEnabled public Purchase_Order__c purchaseOrder { get; set; }
        @AuraEnabled public Account accountRecord { get; set; }
        @AuraEnabled public String objectType { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static Wrapper getPurchaseOrderApprovalData(Id pIWorkItemId, String pageType) {
        Id targetId;

        // Try to get from ProcessInstanceWorkitem
        List<ProcessInstanceWorkitem> workItems = [
            SELECT ProcessInstance.TargetObjectId 
            FROM ProcessInstanceWorkitem 
            WHERE Id = :pIWorkItemId
        ];
        if (!workItems.isEmpty()) {
            targetId = workItems[0].ProcessInstance.TargetObjectId;
        }

        // If not found, try ProcessInstanceStep
        if (targetId == null) {
            List<ProcessInstanceStep> steps = [
                SELECT ProcessInstance.TargetObjectId 
                FROM ProcessInstanceStep 
                WHERE Id = :pIWorkItemId
            ];
            if (!steps.isEmpty()) {
                targetId = steps[0].ProcessInstance.TargetObjectId;
            }
        }

        // If still not found, try directly from ProcessInstance
        if (targetId == null) {
            List<ProcessInstance> processes = [
                SELECT TargetObjectId 
                FROM ProcessInstance 
                WHERE Id = :pIWorkItemId
            ];
            if (!processes.isEmpty()) {
                targetId = processes[0].TargetObjectId;
            }
        }

        // If we still couldn't get the targetId, throw error
        if (targetId == null) {
            throw new AuraHandledException('Target record not found for the given approval work item.');
        }

        // Determine object type
        String sObjType = targetId.getSObjectType().getDescribe().getName();

        // Prepare wrapper
        Wrapper w = new Wrapper();
        w.objectType = sObjType;

        if (sObjType == 'Purchase_Order__c') {
            w.purchaseOrder = [
                SELECT Id, Name, PO_Category__c, PO_Date__c, Quantity__c, Total_Amount__c,
      Opportunity__r.Name, Opportunity__c,
       Quote__r.Name, Quote__c,
       Owner.Name, OwnerId,
       CreatedBy.Name, CreatedDate,
       LastModifiedBy.Name, LastModifiedDate
        FROM Purchase_Order__c
        WHERE Id = :targetId
                LIMIT 1
            ];
        } else if (sObjType == 'Account') {
            w.accountRecord = [
                SELECT Id, Name, Type, Industry, Phone, Website,
                       Bank_Acc_no__c, Bank_Account_Holder_Name__c, Bank_Name__c,
                       Branch__c, Category__c, Company_Email_ID__c, GST_No__c,
                       IFSC__c, PAN__c, TAN__c
                FROM Account
                WHERE Id = :targetId
                LIMIT 1
            ];
        }

        return w;
    }
}





/*public with sharing class purchaseorder {
    public class Wrapper {
        @AuraEnabled public Purchase_Order__c purchaseOrder { get; set; }
        @AuraEnabled public Account accountRecord { get; set; }
        @AuraEnabled public String objectType { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static Wrapper getPurchaseOrderApprovalData(Id pIWorkItemId, String pageType) {
        Id targetId;

        if (pageType == 'Request') {
            targetId = [
                SELECT ProcessInstance.TargetObjectId 
                FROM ProcessInstanceWorkitem 
                WHERE Id = :pIWorkItemId
            ].ProcessInstance.TargetObjectId;
        } else {
            targetId = [
                SELECT ProcessInstance.TargetObjectId 
                FROM ProcessInstanceStep 
                WHERE Id = :pIWorkItemId
            ].ProcessInstance.TargetObjectId;
        }

        String sObjType = targetId.getSObjectType().getDescribe().getName();

        Wrapper w = new Wrapper();
        w.objectType = sObjType;

        if (sObjType == 'Purchase_Order__c') {
            w.purchaseOrder = [
                SELECT Id, Name, PO_Category__c, PO_Date__c, PO_Approval_Status__c
                FROM Purchase_Order__c
                WHERE Id = :targetId
                LIMIT 1
            ];
        } else if (sObjType == 'Account') {
    w.accountRecord = [
        SELECT Id, Name, Type, Industry, Phone, Website,
               Bank_Acc_no__c, Bank_Account_Holder_Name__c, Bank_Name__c,
               Branch__c, Category__c, Company_Email_ID__c, GST_No__c,
               IFSC__c, PAN__c, TAN__c
        FROM Account
        WHERE Id = :targetId
        LIMIT 1
    ];
}

        return w;
    }
}*/