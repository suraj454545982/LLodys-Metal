public class ProformaInvoiceHandler {

    private static final String START_NUMBER = label.Proforma_Number_format; // First Proforma Invoice Number
    
    /**
    * @description Handles before insert operations for Proforma Invoice records
    * @param newInvoices List of new Proforma Invoice records
    */
    public static void handleBeforeInsert(List<Proforma_invoice__c> newInvoices) {
        if (newInvoices == null || newInvoices.isEmpty()) {
            return;
        }

        try {
            assignInvoiceNumbers(newInvoices);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Proforma Invoice number assignment failed: ' + e.getMessage());
            newInvoices[0].addError('Failed to assign Proforma Invoice number: ' + e.getMessage());
        }
    }

    /**
    * @description Assigns 10-digit sequential numbers to new Proforma Invoices
    * @param newInvoices List of Proforma Invoice records
    */
    private static void assignInvoiceNumbers(List<Proforma_invoice__c> newInvoices) {
        
        // Query the highest existing Proforma Invoice Number
        AggregateResult[] maxResults = [
            SELECT MAX(Proforma_Invoice_Number__c) maxNum
            FROM Proforma_invoice__c
            WHERE Proforma_Invoice_Number__c != null
        ];

        Long lastNumber = Long.valueOf(START_NUMBER) - 1;

        if (!maxResults.isEmpty() && maxResults[0].get('maxNum') != null) {
            String maxUsed = (String) maxResults[0].get('maxNum');
            lastNumber = Long.valueOf(maxUsed);
        }

        // Assign numbers sequentially
        for (Proforma_invoice__c inv : newInvoices) {
            lastNumber++;
            inv.Proforma_Invoice_Number__c = String.valueOf(lastNumber).leftPad(10, '0');
        }
    }

    /**
    * @description Prevents manual modification of Proforma_Invoice_Number__c
    */
    public static void handleBeforeUpdate(List<Proforma_invoice__c> newInvoices, Map<Id, Proforma_invoice__c> oldInvoiceMap) {
        for (Proforma_invoice__c inv : newInvoices) {
            Proforma_invoice__c oldInv = oldInvoiceMap.get(inv.Id);
            if (inv.Proforma_Invoice_Number__c != oldInv.Proforma_Invoice_Number__c) {
                inv.addError('Proforma Invoice Number cannot be modified.');
            }
        }
    }
    
    
    
    
   
    
}