trigger QuoteLineItemTrigger on QuoteLineItem (
    before insert,
    before update,
    before delete,
    after insert,
    after update,
    after delete
) {
    Set<Id> quoteIds = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUpdate) {
        for (QuoteLineItem li : Trigger.new) {
            quoteIds.add(li.QuoteId);
        }
    } 
    else if (Trigger.isDelete) {
        for (QuoteLineItem li : Trigger.old) {
            quoteIds.add(li.QuoteId);
        }
    }

    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            OppQuoteLineItemMaterialBlockService.preventAddingOrUpdatingBlockedProducts(
                    Trigger.new,
                    Trigger.isInsert
                );
        }
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        QuoteLineItemTriggerHandler.preventDelete(Trigger.old);
    }

    // Only roll up when records are committed to DB
    if (Trigger.isAfter ) {
        QuoteLineItemTriggerHandler.rollupTaxOnQuote(quoteIds);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {

        Set<Id> qliIds = new Set<Id>();

        for (QuoteLineItem newQLI : Trigger.new) {
            QuoteLineItem oldQLI = Trigger.oldMap.get(newQLI.Id);

            if (
                newQLI.GST_Tax_Percentage__c != oldQLI.GST_Tax_Percentage__c ||
                newQLI.UnitPrice != oldQLI.UnitPrice
            ) {
                qliIds.add(newQLI.Id);
            }
        }

        if (!qliIds.isEmpty()) {
            QuoteLineItemTriggerHandler.pricingRefreshFromQLI(qliIds);
        }
    }
}