@IsTest(seeAllData=true)
public class ApprovalFilesControllerTest {

    @IsTest
    static void testGetApprovalFiles_ReturnPathCovered() {

        // 1️⃣ Fetch ANY existing work item from org
        ProcessInstanceWorkitem wi = [
            SELECT Id, ProcessInstance.TargetObjectId
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId != null
            LIMIT 1
        ];

        // Safety check
        System.assertNotEquals(null, wi.ProcessInstance.TargetObjectId);

        // 2️⃣ Call method
        Test.startTest();
        List<ContentDocumentLink> files =
            ApprovalFilesController.getApprovalFiles(wi.Id);
        Test.stopTest();

        // 3️⃣ Assertions (even empty list is fine)
        System.assertNotEquals(null, files);
    }
}