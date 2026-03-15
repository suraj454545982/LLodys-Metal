Public with sharing class PurchaseOrderTriggerHandler {

    private static Boolean isAfterInsertProcessed = false;

    public static void afterInsert(List<Purchase_Order__c> newList) {
        if (isAfterInsertProcessed) return;
        isAfterInsertProcessed = true;

        // Call helper method
        PurchaseOrderHelper.mapQuoteToPO(newList);

        isAfterInsertProcessed = false;
    }
    
    public static void beforeUpdate(List<Purchase_Order__c> newList,Map<Id, Purchase_Order__c> oldMap) {
          PurchaseOrderHelper.fileValidation(newList,oldMap);
    }
    
    

    
}