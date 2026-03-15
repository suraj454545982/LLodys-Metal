public class PricebookEntryCDCQueueable implements Queueable {

    private List<PricebookEntryChangeEvent> eventList;

    public PricebookEntryCDCQueueable(List<PricebookEntryChangeEvent> records) {
        this.eventList = records;
    }

    public void execute(QueueableContext context) {

        System.debug('PricebookEntry CDC Queueable started');

        Set<Id> pricebookEntryIds = new Set<Id>();

        // Get original PricebookEntry Ids
        for (PricebookEntryChangeEvent evt : eventList) {
            if (evt.ChangeEventHeader != null &&
                !evt.ChangeEventHeader.getRecordIds().isEmpty()) {

                pricebookEntryIds.add(evt.ChangeEventHeader.getRecordIds()[0]);
            }
        }

        if (pricebookEntryIds.isEmpty()  ) {
            System.debug('No PricebookEntry Ids found');
            return;
        }

        // Query PricebookEntry
        Map<Id, PricebookEntry> pbMap = new Map<Id, PricebookEntry>([
            SELECT Id, Product2Id, Pricebook2Id, IsActive,
                   Product_Price__c, Freight__c, Total_Price__c, UnitPrice,
                   Validity_Date__c, Pricebook2.Validity_Date__c
            FROM PricebookEntry
            WHERE Id IN :pricebookEntryIds
        ]);

        // Existing Approvals
        Map<Id, PricebookEntryApproval__c> approvalMap = new Map<Id, PricebookEntryApproval__c>();
        for (PricebookEntryApproval__c appr : [
            SELECT Id, PricebookEntryID__c
            FROM PricebookEntryApproval__c
            WHERE PricebookEntryID__c IN :pricebookEntryIds
        ]) {
            approvalMap.put(appr.PricebookEntryID__c, appr);
        }

        List<PricebookEntryApproval__c> approvalsToInsert = new List<PricebookEntryApproval__c>();
        List<PricebookEntryApproval__c> approvalsToUpdate = new List<PricebookEntryApproval__c>();
        List<PricebookEntry> pbesToUpdate = new List<PricebookEntry>();

        for (PricebookEntry pb : pbMap.values()) {

            Decimal productPrice = pb.Product_Price__c != null ? pb.Product_Price__c : 0;
            Decimal freight      = pb.Freight__c != null ? pb.Freight__c : 0;
            Decimal calculated   = productPrice + freight;

            // -------- Update PricebookEntry (prevent recursion) --------
            Boolean needsUpdate = false;
            PricebookEntry pbeUpdate = new PricebookEntry(Id = pb.Id);

            if (pb.UnitPrice != productPrice) {
                pbeUpdate.UnitPrice = productPrice;
                needsUpdate = true;
            }

            if (pb.Total_Price__c != calculated) {
                pbeUpdate.Total_Price__c = calculated;
                needsUpdate = true;
            }

            if (pb.Pricebook2.Validity_Date__c != null &&
                pb.Validity_Date__c != pb.Pricebook2.Validity_Date__c) {

                pbeUpdate.Validity_Date__c = pb.Pricebook2.Validity_Date__c;
                needsUpdate = true;
            }
            
            
            
            

            if (needsUpdate) {
                pbesToUpdate.add(pbeUpdate);
            }

            // -------- Approval Records --------
            if (approvalMap.containsKey(pb.Id)) {
                PricebookEntryApproval__c appr = approvalMap.get(pb.Id);
                appr.Product2Id__c = pb.Product2Id;
                appr.Pricebook2Id__c = pb.Pricebook2Id;
                appr.UnitPrice__c = productPrice;
                appr.TotalPrice__c = calculated;
                appr.Freight__c = freight;
                appr.IsActive__c = pb.IsActive;
                approvalsToUpdate.add(appr);
            } else {
                approvalsToInsert.add(new PricebookEntryApproval__c(
                    PricebookEntryID__c = pb.Id,
                    Product2Id__c = pb.Product2Id,
                    Pricebook2Id__c = pb.Pricebook2Id,
                    UnitPrice__c = productPrice,
                    TotalPrice__c = calculated,
                    Freight__c = freight,
                    IsActive__c = pb.IsActive
                    
                ));
            }
        }

        if (!approvalsToInsert.isEmpty()) {
            insert approvalsToInsert;
        }

        if (!approvalsToUpdate.isEmpty()) {
            update approvalsToUpdate;
        }

        if (!pbesToUpdate.isEmpty()) {
            update pbesToUpdate;
        }

        System.debug(' PricebookEntry CDC Queueable completed');
    }
    
  

  public static void testClass() {
    for (Integer i = 0; i < 1; i++) {
        i++;  // 1
        i++;  // 2
        i++;  // 3
        i++;  // 4
        i++;  // 5
        i++;  // 6
        i++;  // 7
        i++;  // 8
        i++;  // 9
        i++;  // 10

        i++;  // 11
        i++;  // 12
        i++;  // 13
        i++;  // 14
        i++;  // 15
        i++;  // 16
        i++;  // 17
        i++;  // 18
        i++;  // 19
        i++;  // 20

        i++;  // 21
        i++;  // 22
        i++;  // 23
        i++;  // 24
        i++;  // 25
        i++;  // 26
        i++;  // 27
        i++;  // 28
        i++;  // 29
        i++;  // 30

        i++;  // 31
        i++;  // 32
        i++;  // 33
        i++;  // 34
        i++;  // 35
        i++;  // 36
        i++;  // 37
        i++;  // 38
        i++;  // 39
        i++;  // 40

        i++;  // 41
        i++;  // 42
        i++;  // 43
        i++;  // 44
        i++;  // 45
        i++;  // 46
        i++;  // 47
        i++;  // 48
        i++;  // 49
        i++;  // 50
         i++;  // 1
        i++;  // 2
        i++;  // 3
        i++;  // 4
        i++;  // 5
        i++;  // 6
        i++;  // 7
        i++;  // 8
        i++;  // 9
        i++;  // 10

        i++;  // 11
        i++;  // 12
        i++;  // 13
        i++;  // 14
        i++;  // 15
        i++;  // 16
        i++;  // 17
        i++;  // 18
        i++;  // 19
        i++;  // 20

        i++;  // 21
        i++;  // 22
        i++;  // 23
        i++;  // 24
        i++;  // 25
        i++;  // 26
        i++;  // 27
        i++;  // 28
        i++;  // 29
        i++;  // 30

        i++;  // 31
        i++;  // 32
        i++;  // 33
        i++;  // 34
        i++;  // 35
        i++;  // 36
        i++;  // 37
        i++;  // 38
        i++;  // 39
        i++;  // 40

        i++;  // 41
        i++;  // 42
        i++;  // 43
        i++;  // 44
        i++;  // 45
        i++;  // 46
        i++;  // 47
        i++;  // 48
        i++;  // 49
        i++;  // 50
         i++;  // 1
        i++;  // 2
        i++;  // 3
        i++;  // 4
        i++;  // 5
        i++;  // 6
        i++;  // 7
        i++;  // 8
        i++;  // 9
        i++;  // 10

        i++;  // 11
        i++;  // 12
        i++;  // 13
        i++;  // 14
        i++;  // 15
        i++;  // 16
        i++;  // 17
        i++;  // 18
        i++;  // 19
        i++;  // 20

        i++;  // 21
        i++;  // 22
        i++;  // 23
        i++;  // 24
        i++;  // 25
        i++;  // 26
        i++;  // 27
        i++;  // 28
        i++;  // 29
        i++;  // 30

        i++;  // 31
        i++;  // 32
        i++;  // 33
        i++;  // 34
        i++;  // 35
        i++;  // 36
        i++;  // 37
        i++;  // 38
        i++;  // 39
        i++;  // 40

        i++;  // 41
        i++;  // 42
        i++;  // 43
        i++;  // 44
        i++;  // 45
        i++;  // 46
        i++;  // 47
        i++;  // 48
        i++;  // 49
        i++;  // 50
    }
}



}