/**
* @description Handler class for Contract trigger operations. Maps Purchase Order Line Items
* to Sales Contract Line Items, validates Draft Contracts, remaining quantities, and
* approval quantities. Ensures Contracts are created only for Approved POs and handles
* remaining quantity calculations for multiple Contracts per PO. Calculates proportional
* values for Discount, Freight, Other Expenses, Shipping and Handling, and Packing and
* Forwarding based on per-unit values from PO Line Items. Displays ProductCode in error
* messages for no remaining products.
* @author Simon Christopher P
* @date 2025-09-10
*/
public class SalesContractTriggerHandler {
    
    // MAIN METHOD – After Insert
    public static void mapPOToSalesContract(List<Contract> newContracts) {
        Set<Id> poIds = new Set<Id>();
        for (Contract c : newContracts) {
            if (c.Purchase_Order_Name__c != null) {
                poIds.add(c.Purchase_Order_Name__c);
            }
        }
        if (poIds.isEmpty()) return;
        
        // Block only if same PO has same Quote__c and already has an active contract
        blockCreationIfActiveContractExistsForSamePOAndQuote(newContracts);
        
        // Proceed to create line items
        createLineItemsFromPO(newContracts, poIds);
    }
    
    // ─────────────────────────────────────────────────────
    // 1. BLOCK IF ACTIVE CONTRACT EXISTS FOR SAME PO + SAME QUOTE
    // ─────────────────────────────────────────────────────
    private static void blockCreationIfActiveContractExistsForSamePOAndQuote(List<Contract> newContracts) {
        
        Set<Id> poIds = new Set<Id>();
        for (Contract c : newContracts) {
            if (c.Purchase_Order_Name__c != null) poIds.add(c.Purchase_Order_Name__c);
        }
        if (poIds.isEmpty()) return;
        
        // Query existing contracts (excluding the ones being inserted)
        Map<String, List<Contract>> poAndQuoteToContracts = new Map<String, List<Contract>>();
        
        for (Contract existing : [
            SELECT ContractNumber, ContractApprovalStatus__c,
            Purchase_Order_Name__c, Purchase_Order_Name__r.Quote__c
            FROM Contract
            WHERE Purchase_Order_Name__c IN :poIds
            AND Id NOT IN :newContracts
        ]) {
            String key = existing.Purchase_Order_Name__c + '|' + 
                (existing.Purchase_Order_Name__r.Quote__c != null ? 
                 existing.Purchase_Order_Name__r.Quote__c : 'NO_QUOTE');
            if (!poAndQuoteToContracts.containsKey(key)) {
                poAndQuoteToContracts.put(key, new List<Contract>());
            }
            poAndQuoteToContracts.get(key).add(existing);
        }
        
        // Check each new contract
        for (Contract newCon : newContracts) {
            if (newCon.Purchase_Order_Name__c == null) continue;
            
            Purchase_Order__c po = [SELECT Quote__c FROM Purchase_Order__c WHERE Id = :newCon.Purchase_Order_Name__c LIMIT 1];
            String key = newCon.Purchase_Order_Name__c + '|' + (po.Quote__c != null ? po.Quote__c : 'NO_QUOTE');
            
            List<Contract> conflicts = poAndQuoteToContracts.get(key);
            if (conflicts != null) {
                List<String> active = new List<String>();
                for (Contract c : conflicts) {
                    if (c.ContractApprovalStatus__c == 'Draft') {
                        active.add(c.ContractNumber + ' (Draft)');
                    }
                }
                if (!active.isEmpty()) {
                    newCon.addError(
                        'Cannot create new Sales Contract. Draft Contract(s) exist for this PO ' +
                        String.join(active, ', ') + '. Please Approve or Reject them to create new Sales Contract.'
                    );
                }
            }
        }
    }
    
    // ─────────────────────────────────────────────────────
    // 2. CREATE LINE ITEMS
    // ─────────────────────────────────────────────────────
    private static void createLineItemsFromPO(List<Contract> newContracts, Set<Id> poIds) {
        //Get Approved PO + PO Line Items
        Map<Id, Purchase_Order__c> approvedPOs = new Map<Id, Purchase_Order__c>([
            SELECT Id, Quote__c,Opportunity__r.Category__c,
            (SELECT Product__c, Quantity__c, Sales_Price__c,
             Discount__c, Freight__c, Other_Expenses__c,
             Shipping_and_Handling__c, Packing_and_Forwarding__c,
             GST_Tax_Percentage__c, Product__r.ProductCode
             FROM Purchase_Order_Line_Items1__r)
            FROM Purchase_Order__c
            WHERE Id IN :poIds
            AND PO_Approval_Status__c = 'Approved'
        ]);
        
        Set<Id> quoteIds = new Set<Id>();
        
        for (Purchase_Order__c poRec : approvedPOs.values()) {
            if (poRec.Quote__c != null) {
                quoteIds.add(poRec.Quote__c);
            }
        }
		        
        
        Map<Id, Map<Id, QuoteLineItem>> quoteToProductQLI = new Map<Id, Map<Id, QuoteLineItem>>();

        List<QuoteLineItem> qlis = [
            SELECT Id,
            QuoteId,
            Product2Id,
            PricebookEntryId,
            PricebookEntry.Freight__c,
            PricebookEntry.Royalty__c,
            PricebookEntry.DMT_and_other_taxes__c
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
        ];
        
        for (QuoteLineItem qli : qlis) {
            
            if (!quoteToProductQLI.containsKey(qli.QuoteId)) {
                quoteToProductQLI.put(qli.QuoteId, new Map<Id, QuoteLineItem>());
            }
            
            quoteToProductQLI.get(qli.QuoteId).put(qli.Product2Id, qli);
        }
        
        // Already Approved Quantity per PO + Product
        Map<Id, Map<Id, Decimal>> approvedQtyByPO = new Map<Id, Map<Id, Decimal>>();
        
        for (Sales_Contract_Line_Item__c cli : [
            SELECT Contract__r.Purchase_Order_Name__c,
            Product__c,
            Quantity__c
            FROM Sales_Contract_Line_Item__c
            WHERE Contract__r.Purchase_Order_Name__c IN :poIds
            AND Contract__r.ContractApprovalStatus__c = 'Approved'
        ]) {
            Id poId = cli.Contract__r.Purchase_Order_Name__c;
            
            if (!approvedQtyByPO.containsKey(poId)) {
                approvedQtyByPO.put(poId, new Map<Id, Decimal>());
            }
            
            Map<Id, Decimal> prodMap = approvedQtyByPO.get(poId);
            prodMap.put(
                cli.Product__c,
                (prodMap.containsKey(cli.Product__c)
                 ? prodMap.get(cli.Product__c)
                 : 0
                ) + cli.Quantity__c
            );
        }
        
        List<Sales_Contract_Line_Item__c> linesToInsert =
            new List<Sales_Contract_Line_Item__c>();
        
        //Create Line Items with REMAINING quantity
        for (Contract newCon : newContracts) {
            
            if (newCon.hasErrors() || newCon.Purchase_Order_Name__c == null) {
                continue;
            }
            
            Purchase_Order__c po = approvedPOs.get(newCon.Purchase_Order_Name__c);
            if (po == null) {
                newCon.addError('Purchase Order is not in Approved status.');
                continue;
            }
            
            Boolean hasAtLeastOneLine = false;
            
            for (Purchase_Order_Line_Item__c pli : po.Purchase_Order_Line_Items1__r) {
                
                Decimal poQty = pli.Quantity__c ?? 0;
                Decimal usedQty = 0;
                
                if (
                    approvedQtyByPO.containsKey(po.Id) &&
                    approvedQtyByPO.get(po.Id).containsKey(pli.Product__c)
                ) {
                    usedQty = approvedQtyByPO.get(po.Id).get(pli.Product__c);
                }
                
                Decimal remainingQty = poQty - usedQty;
                
                // No remaining quantity → error
                if (remainingQty <= 0) {
                    continue; // skip this product, do NOT error
                }
                
                hasAtLeastOneLine = true;
                
                Decimal price = pli.Sales_Price__c ?? 0;
                
                Map<Id, QuoteLineItem> productQLIMap =
                    quoteToProductQLI.get(po.Quote__c);
                
                QuoteLineItem matchedQLI =
                    productQLIMap != null ? productQLIMap.get(pli.Product__c) : null;
                
                PricebookEntry pbe =
                    matchedQLI != null ? matchedQLI.PricebookEntry : null;
                
                String pricingJson =
                    PricingConditionController.buildPricingConditionsFromPO(
                        po.Id,
                        price,
                        pli.GST_Tax_Percentage__c,
                        pbe,
                        newCon.CurrencyIsoCode
                    );
                
                //Check Category
                String textItemValue = null;
                
                // Check Category from PO → Opportunity
                if (po.Opportunity__r != null &&
                    po.Opportunity__r.Category__c == 'Iron Ore') {
                        
                        textItemValue = 'Z001';
                    }
                
                
                
                
                linesToInsert.add(new Sales_Contract_Line_Item__c(
                    Contract__c               = newCon.Id,
                    Product__c                = pli.Product__c,
                    Product_Number__c         = pli.Product__r.ProductCode,
                    Quantity__c               = remainingQty,
                    List_Price__c             = price,
                    Amount__c                 = remainingQty * price,
                    Discount__c               = pli.Discount__c,
                    Freight__c                = pli.Freight__c,
                    Other_Expenses__c         = pli.Other_Expenses__c,
                    Shipping_and_Handling__c  = pli.Shipping_and_Handling__c,
                    Packing_and_Forwarding__c = pli.Packing_and_Forwarding__c,
                    GST_Tax_Percentage__c     = pli.GST_Tax_Percentage__c,
                    Pricing_Conditions__c     = pricingJson,
                    Text_Item__c              = textItemValue   
                ));
            }
            
            // If no products had remaining quantity
            if (!hasAtLeastOneLine) {
                newCon.addError(
                    'No remaining quantities available to create Sales Contract.'
                );
            }
        }
        
        // Insert Line Items
        if (!linesToInsert.isEmpty()) {
            try {
                insert linesToInsert;
            } catch (Exception e) {
                for (Contract c : newContracts) {
                    if (!c.hasErrors()) {
                        c.addError(
                            'Failed to create line items: ' + e.getMessage()
                        );
                    }
                }
            }
        }
    }

    
    /**
* BEFORE UPDATE: Prevent re-activation of Rejected Contracts
* if any other Contract (Draft or Approved) already exists for the same PO
*/
    public static void preventReactivatingRejectedContracts(List<Contract> newContracts, Map<Id, Contract> oldMap) {    
        // 1. Find contracts that are moving FROM Rejected TO Draft/Approved
        Set<Id> poIdsToCheck = new Set<Id>();
        for (Contract nc : newContracts) {
            Contract old = oldMap.get(nc.Id);
            if (old.ContractApprovalStatus__c == 'Rejected' &&
                nc.ContractApprovalStatus__c != 'Rejected' &&
                nc.Purchase_Order_Name__c != null) {
                    
                    poIdsToCheck.add(nc.Purchase_Order_Name__c);
                }
        }
        if (poIdsToCheck.isEmpty()) return;
        
        // 2. Find any ACTIVE (Draft or Approved) contract on those POs
        Map<Id, Contract> poToActiveContract = new Map<Id, Contract>();
        for (Contract c : [
            SELECT Id, ContractNumber, Purchase_Order_Name__c
            FROM Contract
            WHERE Purchase_Order_Name__c IN :poIdsToCheck
            AND ContractApprovalStatus__c IN ('Draft', 'Approved')
        ]) {
            poToActiveContract.put(c.Purchase_Order_Name__c, c);
        }
        
        // 3. Block the status change
        for (Contract nc : newContracts) {
            Contract old = oldMap.get(nc.Id);
            
            if (old.ContractApprovalStatus__c == 'Rejected' &&
                nc.ContractApprovalStatus__c != 'Rejected' &&
                nc.Purchase_Order_Name__c != null) {
                    
                    Contract active = poToActiveContract.get(nc.Purchase_Order_Name__c);
                    
                    if (active != null) {
                        nc.addError(
                            'Cannot change this Rejected Sales Contract to ' +
                            nc.ContractApprovalStatus__c + '. ' +
                            'An active Sales Contract (' + active.ContractNumber +
                            ') already exists for this Purchase Order. ' +
                            'Only one active Sales Contract is allowed per PO.'
                        );
                    }
                }
        }
    }
    /**
* Once Contract is Approved → Freeze it completely
* Allow editing only: Trigger_SAP_Insert__c & SAP_Sales_Contract_Number__c
*/
    public static void freezeApprovedContract(List<Contract> newContracts, Map<Id, Contract> oldMap) {
        
        // These two fields are allowed to be edited even after Approval
        Set<String> allowedFields = new Set<String>{
            'Trigger_SAP_Insert__c',
                'SAP_Sales_Contract_Number__c'
                };
                    
                    for (Contract newCon : newContracts) {
                        Contract oldCon = oldMap.get(newCon.Id);
                        
                        // Only apply if Contract is in Approved status
                        if (newCon.ContractApprovalStatus__c == 'Approved') {
                            
                            Boolean onlyAllowedChange = true;
                            
                            for (String field : newCon.getPopulatedFieldsAsMap().keySet()) {
                                // Skip system & allowed fields
                                if (field == 'Id' || 
                                    field == 'ContractApprovalStatus__c' || 
                                    allowedFields.contains(field)) {
                                        continue;
                                    }
                                
                                if (newCon.get(field) != oldCon.get(field)) {
                                    onlyAllowedChange = false;
                                    break;
                                }
                            }
                            
                            if (!onlyAllowedChange) {
                                newCon.addError(
                                    'This Contract is APPROVED and FROZEN.\n' +
                                    'You cannot modify any fields.Contract Number: ' + newCon.ContractNumber
                                );
                            }
                        }
                    }
    }
}