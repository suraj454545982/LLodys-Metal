public without sharing class ApprovalFilesController {

    @AuraEnabled(cacheable=true)
    public static List<ContentDocumentLink> getApprovalFiles(Id workItemId) {

        // Get target record from approval
        ProcessInstanceWorkitem wi = [
            SELECT ProcessInstance.TargetObjectId
            FROM ProcessInstanceWorkitem
            WHERE Id = :workItemId
            LIMIT 1
        ];

        if (wi.ProcessInstance.TargetObjectId == null) {
            return new List<ContentDocumentLink>();
        }

        return [
            SELECT ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.FileType
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :wi.ProcessInstance.TargetObjectId
            ORDER BY ContentDocument.CreatedDate DESC
        ];
    }
}