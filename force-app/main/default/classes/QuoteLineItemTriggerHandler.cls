public class QuoteLineItemTriggerHandler {

    public static void pricingRefreshFromQLI(Set<Id> qliIds) {

        List<QuoteLineItem> qlis = [
            SELECT Id,
                   QuoteId,
                   UnitPrice,
                   GST_Tax_Percentage__c
            FROM QuoteLineItem
            WHERE Id IN :qliIds
        ];

        if (qlis.isEmpty()) return;

        Map<Id, QuoteLineItem> qliMap = new Map<Id, QuoteLineItem>(qlis);

        Set<Id> quoteIds = new Set<Id>();
        for (QuoteLineItem qli : qlis) {
            quoteIds.add(qli.QuoteId);
        }

        Map<Id, Quote> quoteMap = new Map<Id, Quote>([
            SELECT Id,
            BillingStateCode,
            Shipping_Address_Lookup__c,
            Shipping_Address_Lookup__r.Shipping_Address__StateCode__s
            FROM Quote
            WHERE Id IN :quoteIds
        ]);

        List<Purchase_Order__c> pos = [
            SELECT Id,
                   Quote__c
            FROM Purchase_Order__c
            WHERE Quote__c IN :quoteIds
        ];

        if (pos.isEmpty()) return;

        Set<Id> poIds = new Set<Id>();
        Map<Id, Id> poToQuote = new Map<Id, Id>();

        for (Purchase_Order__c po : pos) {
            poIds.add(po.Id);
            poToQuote.put(po.Id, po.Quote__c);
        }

        List<Contract> contracts = [
            SELECT Id,
                   Purchase_Order_Name__c
            FROM Contract
            WHERE Purchase_Order_Name__c IN :poIds
        ];

        if (contracts.isEmpty()) return;

        Map<Id, Id> contractToQuote = new Map<Id, Id>();
        Set<Id> contractIds = new Set<Id>();

        for (Contract c : contracts) {
            contractIds.add(c.Id);
            contractToQuote.put(
                c.Id,
                poToQuote.get(c.Purchase_Order_Name__c)
            );
        }

        List<Sales_Contract_Line_Item__c> clis = [
            SELECT Id,
                   Contract__c,
                   CurrencyIsoCode,
                   Pricing_Conditions__c
            FROM Sales_Contract_Line_Item__c
            WHERE Contract__c IN :contractIds
        ];

        if (clis.isEmpty()) return;

        for (Sales_Contract_Line_Item__c cli : clis) {

            Id quoteId = contractToQuote.get(cli.Contract__c);
            if (quoteId == null) continue;

            Quote q = quoteMap.get(quoteId);
            if (q == null) continue;

            for (QuoteLineItem qli : qlis) {
                if (qli.QuoteId == quoteId) {
                    PricingConditionController.rebuildPricingFromQLI(
                        cli,
                        q,
                        qli
                    );
                    break;
                }
            }
        }

        update clis;
    }


    // Preventing the user from deleting the Quote Line Item
    public static void preventDelete(List<QuoteLineItem> oldList) {
        for (QuoteLineItem qli : oldList) {
            qli.addError(
                'You cannot delete the Line Item. If you want to remove any products, ' +
                'delete the Quote, remove products in Opportunity, and create a new Quote.'
            );
        }
    }


    public static void rollupTaxOnQuote(Set<Id> quoteIds) {

        if (quoteIds.isEmpty()) return;

        // Query all QuoteLineItems for the affected Quotes
        List<QuoteLineItem> lineItems = [
            SELECT Id,
                   QuoteId,
                   CGST__c,
                   SGST__c,
                   IGST__c,
                   Total_Amount__c
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
        ];

        // Aggregate sums by QuoteId
        Map<Id, Decimal> cgstSums = new Map<Id, Decimal>();
        Map<Id, Decimal> sgstSums = new Map<Id, Decimal>();
        Map<Id, Decimal> igstSums = new Map<Id, Decimal>();
        Map<Id, Decimal> totalAmount = new Map<Id, Decimal>();

        for (QuoteLineItem li : lineItems) {

            cgstSums.put(
                li.QuoteId,
                (cgstSums.get(li.QuoteId) == null ? 0 : cgstSums.get(li.QuoteId)) +
                (li.CGST__c == null ? 0 : li.CGST__c)
            );

            sgstSums.put(
                li.QuoteId,
                (sgstSums.get(li.QuoteId) == null ? 0 : sgstSums.get(li.QuoteId)) +
                (li.SGST__c == null ? 0 : li.SGST__c)
            );

            igstSums.put(
                li.QuoteId,
                (igstSums.get(li.QuoteId) == null ? 0 : igstSums.get(li.QuoteId)) +
                (li.IGST__c == null ? 0 : li.IGST__c)
            );

            totalAmount.put(
                li.QuoteId,
                (totalAmount.get(li.QuoteId) == null ? 0 : totalAmount.get(li.QuoteId)) +
                (li.Total_Amount__c == null ? 0 : li.Total_Amount__c)
            );
        }

        // Query Quotes and update them
        List<Quote> quotesToUpdate = new List<Quote>();

        for (Id qId : quoteIds) {

            System.debug(
                qId + ' ' +
                (cgstSums.get(qId) == null ? 0 : cgstSums.get(qId)) + ' ' +
                (sgstSums.get(qId) == null ? 0 : sgstSums.get(qId)) + ' ' +
                (igstSums.get(qId) == null ? 0 : igstSums.get(qId))
            );

            Quote q = new Quote(
                Id                     = qId,
                CGST__c                = cgstSums.get(qId) == null ? 0 : cgstSums.get(qId),
                SGST__c                = sgstSums.get(qId) == null ? 0 : sgstSums.get(qId),
                IGST__c                = igstSums.get(qId) == null ? 0 : igstSums.get(qId),
                Quote_Grand_Total_New__c =
                    totalAmount.get(qId) == null ? 0 : totalAmount.get(qId)
            );
            System.debug('CGST '+cgstSums.get(qId) == null ? 0 : cgstSums.get(qId));
            System.debug('SGST '+sgstSums.get(qId) == null ? 0 : sgstSums.get(qId));
            System.debug('IGST '+igstSums.get(qId) == null ? 0 : igstSums.get(qId));

            quotesToUpdate.add(q);
        }

        if (!quotesToUpdate.isEmpty()) {
            update quotesToUpdate;
        }
    }
}