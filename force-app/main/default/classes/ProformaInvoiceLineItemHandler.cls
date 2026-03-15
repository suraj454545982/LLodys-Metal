public with sharing class ProformaInvoiceLineItemHandler {

    @TestVisible
    private static Boolean isFirstRun = true;

    public static void setFirstRun(Boolean value) { isFirstRun = value; }
    public static Boolean getFirstRun() { return isFirstRun; }

    // Before Insert / Update
    public static void handleBeforeInsertUpdate(List<Proforma_Invoice_Line_Item__c> newLines, Map<Id, Proforma_Invoice_Line_Item__c> oldMap) {
        // Populate Sales Price
        ProformaInvoiceLineItemHelper.populateSalesPrice(newLines);

        // Validate remaining quantity (both insert & update)
        ProformaInvoiceLineItemHelper.validateRemainingQuantity(newLines,oldMap);
    }

    // After Insert / Update / Delete
    public static void handleAfterInsertUpdateDelete(List<Proforma_Invoice_Line_Item__c> newLines, List<Proforma_Invoice_Line_Item__c> oldLines) {
        if (!getFirstRun()) return;
        setFirstRun(false);

        Set<Id> piIds = new Set<Id>();
        if (newLines != null) for (Proforma_Invoice_Line_Item__c li : newLines) piIds.add(li.Proforma_Invoice__c);
        if (oldLines != null) for (Proforma_Invoice_Line_Item__c li : oldLines) piIds.add(li.Proforma_Invoice__c);

        if (!piIds.isEmpty()) {
            ProformaInvoiceLineItemHelper.updateProformaInvoiceTotals(piIds);
        }

        setFirstRun(true);
    }
}