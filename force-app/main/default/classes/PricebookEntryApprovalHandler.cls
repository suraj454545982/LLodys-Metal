public class PricebookEntryApprovalHandler {

    // After Insert → update PricebookEntry lookup
    public static void handleAfterInsert(List<PricebookEntryApproval__c> newList) {
        Map<Id, Id> pbToApprovalMap = new Map<Id, Id>();

        for (PricebookEntryApproval__c appr : newList) {
            if (appr.PricebookEntryID__c != null) {
                pbToApprovalMap.put(appr.PricebookEntryID__c, appr.Id);
            }
        }

        if (!pbToApprovalMap.isEmpty()) {
            List<PricebookEntry> pbToUpdate = [
                SELECT Id, PricebookEntryApproval__c
                FROM PricebookEntry
                WHERE Id IN :pbToApprovalMap.keySet()
            ];

            for (PricebookEntry pb : pbToUpdate) {
                pb.PricebookEntryApproval__c = pbToApprovalMap.get(pb.Id);
            }

            if (!pbToUpdate.isEmpty()) {
                try {
                    update pbToUpdate;
                } catch (DmlException e) {
                    System.debug(' Error updating PricebookEntry: ' + e.getMessage());
                }
            }
        }
    }

   // After Update → sync ApprovalStatus field
public static void handleAfterUpdate(List<PricebookEntryApproval__c> newList, 
                                     Map<Id, PricebookEntryApproval__c> oldMap) {
    
    Map<Id, String> pbStatusMap = new Map<Id, String>();

    for (PricebookEntryApproval__c appr : newList) {
        PricebookEntryApproval__c oldAppr = oldMap.get(appr.Id);

        // Only process when ApprovalStatus__c has changed AND lookup exists
        if (appr.ApprovalStatus__c != oldAppr.ApprovalStatus__c &&
            appr.PricebookEntryID__c != null) {

            pbStatusMap.put(appr.PricebookEntryID__c, appr.ApprovalStatus__c);
        }
    }

    if (!pbStatusMap.isEmpty()) {
        List<PricebookEntry> pbToUpdate = [
            SELECT Id, ApprovalStatus_c__c
            FROM PricebookEntry
            WHERE Id IN :pbStatusMap.keySet()
        ];

        for (PricebookEntry pb : pbToUpdate) {
            pb.ApprovalStatus_c__c = pbStatusMap.get(pb.Id);
        }

        if (!pbToUpdate.isEmpty()) {
            try {
                update pbToUpdate;
            } catch (DmlException e) {
                System.debug(' Error updating PricebookEntry ApprovalStatus: ' + e.getMessage());
            }
        }
    }
}

    
     /*
     * -------------------------------
     *   INSERT APPROVAL SUBMISSION
     * -------------------------------
     */
    public static void insertApprove(List<PricebookEntryApproval__c> newList) {
        submitForApproval(newList, null);
    }

    /*
     * -------------------------------
     *   UPDATE APPROVAL SUBMISSION
     *   Only trigger if Unit Price changed
     * -------------------------------
     */
    public static void updateApprove(List<PricebookEntryApproval__c> newList,
                                     Map<Id, PricebookEntryApproval__c> oldMap) {

        List<PricebookEntryApproval__c> toSubmit = new List<PricebookEntryApproval__c>();

        for (PricebookEntryApproval__c rec : newList) {
            PricebookEntryApproval__c oldRec = oldMap.get(rec.Id);

            // Only submit if Unit Price changed
            if (rec.UnitPrice__c != oldRec.UnitPrice__c) {
                toSubmit.add(rec);
            }
        }

        if (!toSubmit.isEmpty()) {
            submitForApproval(toSubmit, oldMap);
        }
    }


    /*
     * ---------------------------------------
     *   MAIN APPROVAL SUBMISSION LOGIC
     *   Uses PRODUCT FAMILY to pick process
     * ---------------------------------------
     */
   public static void submitForApproval(List<PricebookEntryApproval__c> recList,
                                     Map<Id, PricebookEntryApproval__c> oldMap) {

    // ️ Collect Product2 IDs
    Set<Id> productIds = new Set<Id>();
    for (PricebookEntryApproval__c rec : recList) {
        if (rec.Product2Id__c != null) {
            productIds.add(rec.Product2Id__c);
        }
    }

    //  Query Product2
    Map<Id, Product2> prodMap = new Map<Id, Product2>(
        [SELECT Id, Family FROM Product2 WHERE Id IN :productIds]
    );

    // Loop and route to correct approval process
    for (PricebookEntryApproval__c rec : recList) {

        Product2 prod = prodMap.get(rec.Product2Id__c);
        if (prod == null) continue;

        String processName;
    system.debug('prod.Family---->'+prod.Family);
        if (prod.Family == 'DRI') {
            processName = System.Label.DRIApproval_PricebookEntry;
        }
        else if (prod.Family == 'Iron Ore') {
            processName = System.Label.IronOreApproval_PricebookEntry;
        }
        else if (prod.Family == 'Iron Ore Pellet') {
            processName = System.Label.PelletApproval_PricebookEntry;
        }
        else {
            continue; // unknown family -> skip
        }

        try {
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(rec.Id);
            req.setSubmitterId(UserInfo.getUserId());
            req.setProcessDefinitionNameOrId(processName);

            Approval.ProcessResult result = Approval.process(req);

            System.debug('Submitted to Process: ' + processName + ' for record: ' + rec.Id);
        }
        catch (Exception e) {
            System.debug('Approval error: ' + e.getMessage());
        }
    }
}
    
    /**
 * Validates that a user provides rejection comments when rejecting a record
 * in the Approval Process for PricebookEntryApproval__c.
 *
 * This works the same way as the Account rejection validation you provided.
 */
public static void validatePBRejectComments(List<PricebookEntryApproval__c> newList,
                                             Map<Id, PricebookEntryApproval__c> oldMap) 
{
    // Map to collect records where status changed TO "Rejected"
    Map<Id, PricebookEntryApproval__c> rejectedRecords = new Map<Id, PricebookEntryApproval__c>();

    // -----------------------------------------------------------
    // Identify records whose ApprovalStatus changed → Rejected
    // -----------------------------------------------------------
    for (PricebookEntryApproval__c rec : newList) {
        PricebookEntryApproval__c oldRec = oldMap.get(rec.Id);

        if (
            oldRec.ApprovalStatus__c != null &&
            rec.ApprovalStatus__c != null &&
            oldRec.ApprovalStatus__c.toLowerCase() != 'rejected' &&
            rec.ApprovalStatus__c.toLowerCase() == 'rejected'
        ) {
            rejectedRecords.put(rec.Id, rec);
        }
    }

    // If nothing was rejected → no need to check comments
    if (rejectedRecords.isEmpty()) return;

    // ---------------------------------------------------------
    // Query latest ProcessInstance for each rejected record
    //    This contains the approval/rejection flow history.
    // ---------------------------------------------------------
    List<Id> processInstanceIds = new List<Id>();

    List<PricebookEntryApproval__c> recsWithPI = [
        SELECT (SELECT Id 
                FROM ProcessInstances 
                ORDER BY CreatedDate DESC 
                LIMIT 1)
        FROM PricebookEntryApproval__c
        WHERE Id IN :rejectedRecords.keySet()
    ];

    // Extract ProcessInstance Ids
    for (PricebookEntryApproval__c rec : recsWithPI) {
        if (!rec.ProcessInstances.isEmpty()) {
            processInstanceIds.add(rec.ProcessInstances[0].Id);
        }
    }

    if (processInstanceIds.isEmpty()) return;

    // -----------------------------------------------------------------
       //From each ProcessInstance, fetch the most recent *Rejected* step
    //    This contains the "Comments" entered by the rejecting approver.
    // -----------------------------------------------------------------
    List<ProcessInstance> processInstances = [
        SELECT TargetObjectId,
               (SELECT Id, StepStatus, Comments
                FROM Steps
                WHERE StepStatus = 'Rejected'
                ORDER BY CreatedDate DESC
                LIMIT 1)
        FROM ProcessInstance
        WHERE Id IN :processInstanceIds
    ];

    // ------------------------------------------------—————
    //  Validate the comment → must NOT be empty or null
    // ------------------------------------------------—————
    for (ProcessInstance pi : processInstances) {

        // If no rejection step OR no comment entered → throw error
        if (
            pi.Steps.isEmpty() ||
            pi.Steps[0].Comments == null ||
            pi.Steps[0].Comments.trim().length() == 0
        ) {
            rejectedRecords.get(pi.TargetObjectId)
                .addError('Please provide a rejection reason!');
        }
    }
}
       
}