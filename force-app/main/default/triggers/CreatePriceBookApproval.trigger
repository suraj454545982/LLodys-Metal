Trigger CreatePriceBookApproval on Pricebook2 (after insert) {
   /* List<PriceBook_Approval__c> approvalsToInsert = new List<PriceBook_Approval__c>();

    for (Pricebook2 pb : Trigger.new) {
        PriceBook_Approval__c approval = new PriceBook_Approval__c();
        approval.Price_Book__c = pb.Id; 
        approvalsToInsert.add(approval);
    }

    if (!approvalsToInsert.isEmpty()) {
        insert approvalsToInsert;
    } */
}