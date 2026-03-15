/**
* @description Handler class for Sales_Contract_Line_Item__c trigger operations. Populates
* List_Price__c from Purchase_Order_Line_Item__c.Sales_Price__c on insert, recalculates
* Amount__c, Discount__c, Freight__c, Other_Expenses__c, Shipping_and_Handling__c, and
* Packing_and_Forwarding__c proportionally based on per-unit values from PO Line Items and
* validates Quantity__c against remaining Purchase Order quantities on update, and rolls up
* CGST, SGST, IGST to parent Contract on insert, update, and delete. Displays ProductCode
* in error messages for no matching Purchase Order Line Items.
* @author Simon Christopher P
* @date 2025-09-17
*/
public class SalesContractLineItemTriggerHandler {
    
    // Recursion guard to prevent infinite loops from Contract updates
    private static Boolean isRunningRollup = false;
    private static Boolean isRunningPopulate = false;
    
    public static void preventEditOnBlockedLineItems(List<Sales_Contract_Line_Item__c> newLineItems,Map<Id, Sales_Contract_Line_Item__c> oldMap) {
        System.debug('--- preventEditOnBlockedLineItems START ---');
        for (Sales_Contract_Line_Item__c newLine : newLineItems) {
            
            Sales_Contract_Line_Item__c oldLine = oldMap.get(newLine.Id);
            System.debug('Processing Line Item Id: ' + newLine.Id);
            System.debug('Old Reason: ' + oldLine.Reason_for_Rejection__c);
            System.debug('New Reason: ' + newLine.Reason_for_Rejection__c);
            
            // If Reason_for_Rejection__c has value → line is BLOCKED
            if (String.isNotBlank(newLine.Reason_for_Rejection__c)) {
                
                Boolean onlyReasonChanged = true;
                
                // Check if any field other than Reason_for_Rejection__c was changed
                for (String fieldName : newLine.getPopulatedFieldsAsMap().keySet()) {
                    if (fieldName == 'Id' || fieldName == 'Reason_for_Rejection__c' || fieldName == 'Name' || fieldName == 'Contract_Document_Item_Number__c') {
                        continue; // Skip system/auto-number fields
                    }
                    
                    if (newLine.get(fieldName) != oldLine.get(fieldName)) {
                        onlyReasonChanged = false;
                        break;
                    }
                }
                
                // If user tried to edit anything except Reason → BLOCK
                if (!onlyReasonChanged) {
                    newLine.addError(
                        'Line Item ' + newLine.Name + ' is BLOCKED because "Reason for Rejection" is set. ' +
                        'You cannot modify any field except "Reason for Rejection". ' +
                        'To edit other fields, please Unblock the line item first.'
                    );
                }
                // If only Reason_for_Rejection__c changed → allowed
            }
        }
    }
    
    
    public static void preventEditOnApprovedContractLineItems(
        List<Sales_Contract_Line_Item__c> newLines,
        Map<Id, Sales_Contract_Line_Item__c> oldMap
    ) {
        Set<Id> contractIds = new Set<Id>();
        for (Sales_Contract_Line_Item__c line : newLines) {
            if (line.Contract__c != null) contractIds.add(line.Contract__c);
        }
        
        Map<Id, Contract> approvedContracts = new Map<Id, Contract>([
            SELECT Id FROM Contract 
            WHERE Id IN :contractIds 
            AND ContractApprovalStatus__c = 'Approved'
        ]);
        
        for (Sales_Contract_Line_Item__c newLine : newLines) {
            if (approvedContracts.containsKey(newLine.Contract__c)) {
                Sales_Contract_Line_Item__c oldLine = oldMap.get(newLine.Id);
                
                Boolean onlyReasonChanged = true;
                for (String field : newLine.getPopulatedFieldsAsMap().keySet()) {
                    if (field == 'Id' || field == 'Reason_for_Rejection__c' || field == 'Contract_Document_Item_Number__c') continue;
                    
                    if (newLine.get(field) != oldLine.get(field)) {
                        onlyReasonChanged = false;
                        break;
                    }
                }
                
                if (!onlyReasonChanged) {
                    newLine.addError(
                        'This Line Item belongs to an APPROVED Contract and is FROZEN.\n' +
                        'Only "Reason for Rejection" can be edited.\n' +
                        'Line Item: ' + newLine.Name
                    );
                }
            }
        }
    }
    
    /**
* Before SAP sync → Reason_for_Rejection__c MUST be blank
* After SAP sync → user CAN fill or edit it freely
*/
    public static void preventRejectionReasonBeforeSAPSync(List<Sales_Contract_Line_Item__c> newLineItems,Map<Id, Sales_Contract_Line_Item__c> oldMap) {
        // Collect parent Contract Ids
        Set<Id> contractIds = new Set<Id>();
        for (Sales_Contract_Line_Item__c line : newLineItems) {
            if (line.Contract__c != null) {
                contractIds.add(line.Contract__c);
            }
        }
        if (contractIds.isEmpty()) return;
        
        // Get parent Contract → check SAP number
        Map<Id, Contract> contractMap = new Map<Id, Contract>(
            [SELECT Id, SAP_Sales_Contract_Number__c 
             FROM Contract 
             WHERE Id IN :contractIds]
        );
        
        for (Sales_Contract_Line_Item__c line : newLineItems) {
            Contract parent = contractMap.get(line.Contract__c);
            Boolean isSapSynced = (parent != null && String.isNotBlank(parent.SAP_Sales_Contract_Number__c));
            
            // ONLY apply rule if NOT synced to SAP yet
            if (!isSapSynced && String.isNotBlank(line.Reason_for_Rejection__c)) {
                line.Reason_for_Rejection__c = null; // Force clear
                
                line.addError(
                    'Reason for Rejection cannot be selected until the Sales Contract is synced to SAP. ' +
                    'The value has been cleared automatically.'
                );
            }
            // If SAP number exists → allow any value (including edit) → no action
        }
    }
    
    
    /**
* @description Populates List_Price__c from Purchase_Order_Line_Item__c.Sales_Price__c
* and calculates Amount__c for manually inserted Sales Contract Line Items.
* @param newLines List of new Sales_Contract_Line_Item__c records
*/
    public static void populateListPrice(List<Sales_Contract_Line_Item__c> newLines) {
        
        if (isRunningPopulate) {
            return;
        }
        isRunningPopulate = true;
        
        
        try{        
            Set<Id> contractIds = new Set<Id>();
            Set<Id> productIds = new Set<Id>();
            for (Sales_Contract_Line_Item__c line : newLines) {
                if (line.Contract__c != null) {
                    contractIds.add(line.Contract__c);
                }
                if (line.Product__c != null) {
                    productIds.add(line.Product__c);
                }
            }
            
            if (contractIds.isEmpty() || productIds.isEmpty()) {
                return;
            }
            
            // Query Contracts for Purchase_Order_Name__c
            Map<Id, Contract> contractMap = new Map<Id, Contract>([
                SELECT Id, Purchase_Order_Name__c
                FROM Contract
                WHERE Id IN :contractIds
            ]);
            
            Set<Id> poIds = new Set<Id>();
            for (Contract contract : contractMap.values()) {
                if (contract.Purchase_Order_Name__c != null) {
                    poIds.add(contract.Purchase_Order_Name__c);
                }
            }
            
            // Query Purchase Order Line Items for Sales_Price__c
            Map<String, Decimal> poProductToPrice = new Map<String, Decimal>();
            for (Purchase_Order_Line_Item__c pli : [
                SELECT Purchase_Order__c, Product__c, Sales_Price__c
                FROM Purchase_Order_Line_Item__c
                WHERE Purchase_Order__c IN :poIds AND Product__c IN :productIds
            ]) {
                poProductToPrice.put(pli.Purchase_Order__c + '-' + pli.Product__c, pli.Sales_Price__c);
            }
            
            // Query Product2 for ProductCode
            Map<Id, String> productToNumber = new Map<Id, String>();
            for (Product2 prod : [SELECT Id, ProductCode FROM Product2 WHERE Id IN :productIds]) {
                productToNumber.put(prod.Id, prod.ProductCode != null ? prod.ProductCode : 'Unknown');
            }
            
            // Populate List_Price__c and Amount__c
            for (Sales_Contract_Line_Item__c line : newLines) {
                if (line.List_Price__c == null && line.Product__c != null && line.Contract__c != null) {
                    Contract contract = contractMap.get(line.Contract__c);
                    if (contract != null && contract.Purchase_Order_Name__c != null) {
                        String key = contract.Purchase_Order_Name__c + '-' + line.Product__c;
                        Decimal unitPrice = poProductToPrice.get(key);
                        if (unitPrice != null) {
                            line.List_Price__c = unitPrice;
                            line.Product_Number__c = productToNumber.get(line.Product__c);
                            if (line.Quantity__c != null) {
                                line.Amount__c = line.Quantity__c * unitPrice;
                            }
                        } else {
                            line.addError('Cannot populate List Price: No matching Purchase Order Line Item for Product ' + line.Product_Number__c);
                        }
                    }
                }
            }
            
        }
        finally{
            isRunningPopulate = false;
        }
    }
    
    /**
* @description Recalculates Amount__c, Discount__c, Freight__c, Other_Expenses__c,
* Shipping_and_Handling__c, and Packing_and_Forwarding__c proportionally based on per-unit
* values from Purchase Order Line Items and validates Quantity__c against remaining
* Purchase Order quantities on update. Ensures updated quantities do not exceed the PO limit.
* @param newLines List of updated Sales_Contract_Line_Item__c records
* @param oldMap Map of old Sales_Contract_Line_Item__c records
*/
    public static void recalculateAmountAndValidateLimit(List<Sales_Contract_Line_Item__c> newLines, Map<Id, Sales_Contract_Line_Item__c> oldMap) {
        Set<Id> contractIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        Set<Id> poIds = new Set<Id>();
        for (Sales_Contract_Line_Item__c line : newLines) {
            Sales_Contract_Line_Item__c oldLine = oldMap.get(line.Id);
            if (line.Quantity__c != oldLine.Quantity__c) {
                contractIds.add(line.Contract__c);
                productIds.add(line.Product__c);
            }
        }
        
        if (contractIds.isEmpty() || productIds.isEmpty()) {
            return;
        }
        
        // Query Contracts for Purchase_Order_Name__c and ContractApprovalStatus__c
        Map<Id, Contract> contractMap = new Map<Id, Contract>([
            SELECT Id, Purchase_Order_Name__c, ContractApprovalStatus__c
            FROM Contract
            WHERE Id IN :contractIds
        ]);
        
        for (Contract contract : contractMap.values()) {
            if (contract.Purchase_Order_Name__c != null) {
                poIds.add(contract.Purchase_Order_Name__c);
            }
        }
        
        // Query PO Line Items for original quantities and fields
        Map<String, Decimal> poProductToQty = new Map<String, Decimal>();
        Map<String, Decimal> poProductToDiscount = new Map<String, Decimal>();
        Map<String, Decimal> poProductToFreight = new Map<String, Decimal>();
        Map<String, Decimal> poProductToOtherExpenses = new Map<String, Decimal>();
        Map<String, Decimal> poProductToShipping = new Map<String, Decimal>();
        Map<String, Decimal> poProductToPacking = new Map<String, Decimal>();
        for (Purchase_Order_Line_Item__c pli : [
            SELECT Purchase_Order__c, Product__c, Quantity__c, Discount__c, Freight__c, 
            Other_Expenses__c, Shipping_and_Handling__c, Packing_and_Forwarding__c
            FROM Purchase_Order_Line_Item__c
            WHERE Purchase_Order__c IN :poIds AND Product__c IN :productIds
        ]) {
            String key = pli.Purchase_Order__c + '-' + pli.Product__c;
            poProductToQty.put(key, pli.Quantity__c);
            poProductToDiscount.put(key, pli.Discount__c);
            poProductToFreight.put(key, pli.Freight__c);
            poProductToOtherExpenses.put(key, pli.Other_Expenses__c);
            poProductToShipping.put(key, pli.Shipping_and_Handling__c);
            poProductToPacking.put(key, pli.Packing_and_Forwarding__c);
        }
        
        // Query total approved Contract Line Items quantities per product per PO
        Map<String, Decimal> poProductToApprovedQty = new Map<String, Decimal>();
        for (Sales_Contract_Line_Item__c approvedLine : [
            SELECT Product__c, Quantity__c, Contract__r.Purchase_Order_Name__c
            FROM Sales_Contract_Line_Item__c
            WHERE Contract__r.Purchase_Order_Name__c IN :poIds
            AND Contract__r.ContractApprovalStatus__c = 'Approved'
            AND Product__c IN :productIds
        ]) {
            String key = approvedLine.Contract__r.Purchase_Order_Name__c + '-' + approvedLine.Product__c;
            Decimal currentSum = poProductToApprovedQty.get(key) != null ? poProductToApprovedQty.get(key) : 0;
            poProductToApprovedQty.put(key, currentSum + approvedLine.Quantity__c);
        }
        
        // Process each updated line
        for (Sales_Contract_Line_Item__c line : newLines) {
            Sales_Contract_Line_Item__c oldLine = oldMap.get(line.Id);
            if (line.Quantity__c != oldLine.Quantity__c) {
                // Recalculate Amount__c
                Decimal listPrice = line.List_Price__c != null ? line.List_Price__c : 0;
                Decimal quantity = line.Quantity__c != null ? line.Quantity__c : 0;
                line.Amount__c = quantity * listPrice;
                
                // Recalculate proportional fields
                Contract contract = contractMap.get(line.Contract__c);
                if (contract != null && contract.Purchase_Order_Name__c != null && line.Product__c != null) {
                    String poKey = contract.Purchase_Order_Name__c + '-' + line.Product__c;
                    Decimal origQty = poProductToQty.get(poKey) != null ? poProductToQty.get(poKey) : 0;
                    
                    // Per-unit calculations
                    //Decimal perUnitDiscount = (poProductToDiscount.get(poKey) != null && origQty > 0) ? poProductToDiscount.get(poKey) / origQty : 0;
                    Decimal perUnitFreight = (poProductToFreight.get(poKey) != null && origQty > 0) ? poProductToFreight.get(poKey) / origQty : 0;
                    Decimal perUnitOtherExpenses = (poProductToOtherExpenses.get(poKey) != null && origQty > 0) ? poProductToOtherExpenses.get(poKey) / origQty : 0;
                    Decimal perUnitShipping = (poProductToShipping.get(poKey) != null && origQty > 0) ? poProductToShipping.get(poKey) / origQty : 0;
                    Decimal perUnitPacking = (poProductToPacking.get(poKey) != null && origQty > 0) ? poProductToPacking.get(poKey) / origQty : 0;
                    
                    // Proportional values
                    //line.Discount__c = perUnitDiscount * quantity;
                    line.Freight__c = perUnitFreight * quantity;
                    line.Other_Expenses__c = perUnitOtherExpenses * quantity;
                    line.Shipping_and_Handling__c = perUnitShipping * quantity;
                    line.Packing_and_Forwarding__c = perUnitPacking * quantity;
                }
                
                // Validate Quantity limit
                if (contract != null && contract.Purchase_Order_Name__c != null && line.Product__c != null) {
                    String poKey = contract.Purchase_Order_Name__c + '-' + line.Product__c;
                    Decimal poQty = poProductToQty.get(poKey) != null ? poProductToQty.get(poKey) : 0;
                    
                    String approvedKey = contract.Purchase_Order_Name__c + '-' + line.Product__c;
                    Decimal totalApproved = poProductToApprovedQty.get(approvedKey) != null ? poProductToApprovedQty.get(approvedKey) : 0;
                    
                    // Subtract old quantity only if parent Contract is Approved
                    if (contract.ContractApprovalStatus__c == 'Approved') {
                        totalApproved -= oldLine.Quantity__c;
                    }
                    
                    Decimal remainingLimit = poQty - totalApproved;
                    System.debug('Limit check for Product ' + line.Product__c + ': PO Qty = ' + poQty + ', Total Approved (adjusted) = ' + totalApproved + ', Remaining Limit = ' + remainingLimit + ', New Qty = ' + line.Quantity__c);
                    
                    if (line.Quantity__c > remainingLimit) {
                        line.addError('Quantity exceeds remaining Purchase Order quantity for Product ' + line.Product_Number__c + '. Remaining limit: ' + remainingLimit);
                    }
                }
            }
        }
    }
    
    /**
* @description Rolls up CGST, SGST, and IGST from Sales_Contract_Line_Item__c records
* to their parent Contract records for the specified Contract IDs.
* @param contractIds Set of Contract IDs to process
*/
    public static void rollupTaxOnContract(Set<Id> contractIds) {
        if (contractIds.isEmpty() || isRunningRollup) {
            return;
        }
        isRunningRollup = true;
        
        // Query all Sales Contract Line Items for the affected Contracts
        List<Sales_Contract_Line_Item__c> lineItems = [
            SELECT Id, Contract__c, CGST__c, SGST__c, IGST__c
            FROM Sales_Contract_Line_Item__c
            WHERE Contract__c IN :contractIds
        ];
        
        // Aggregate sums by ContractId
        Map<Id, Decimal> cgstSums = new Map<Id, Decimal>();
        Map<Id, Decimal> sgstSums = new Map<Id, Decimal>();
        Map<Id, Decimal> igstSums = new Map<Id, Decimal>();
        for (Sales_Contract_Line_Item__c li : lineItems) {
            cgstSums.put(li.Contract__c, (cgstSums.get(li.Contract__c) == null ? 0 : cgstSums.get(li.Contract__c)) + (li.CGST__c == null ? 0 : li.CGST__c));
            sgstSums.put(li.Contract__c, (sgstSums.get(li.Contract__c) == null ? 0 : sgstSums.get(li.Contract__c)) + (li.SGST__c == null ? 0 : li.SGST__c));
            igstSums.put(li.Contract__c, (igstSums.get(li.Contract__c) == null ? 0 : igstSums.get(li.Contract__c)) + (li.IGST__c == null ? 0 : li.IGST__c));
        }
        
        // Query Contracts and update them
        List<Contract> contractsToUpdate = new List<Contract>();
        for (Id cId : contractIds) {
            System.debug(cId + ' CGST: ' + (cgstSums.get(cId) == null ? 0 : cgstSums.get(cId)) + ' SGST: ' + (sgstSums.get(cId) == null ? 0 : sgstSums.get(cId)) + ' IGST: ' + (igstSums.get(cId) == null ? 0 : igstSums.get(cId)));
            Contract c = new Contract(
                Id = cId,
                CGST__c = cgstSums.get(cId) == null ? 0 : cgstSums.get(cId),
                SGST__c = sgstSums.get(cId) == null ? 0 : sgstSums.get(cId),
                IGST__c = igstSums.get(cId) == null ? 0 : igstSums.get(cId)
            );
            contractsToUpdate.add(c);
        }
        
        if (!contractsToUpdate.isEmpty()) {
            try {
                update contractsToUpdate;
            } catch (Exception e) {
                System.debug('Error updating Contracts with tax rollup: ' + e.getMessage());
            }
        }
        
        isRunningRollup = false;
    }
    
    public static void validatePricebookPlant(List<Sales_Contract_Line_Item__c> records){
        
        Set<Id> contractIds = new Set<Id>();
        
        for(Sales_Contract_Line_Item__c rec : records){
            if(rec.Contract__c != null){
                contractIds.add(rec.Contract__c);
            }
        }
        
        if(contractIds.isEmpty()) return;
        
        Map<Id, Contract> contractMap = new Map<Id, Contract>(
            [SELECT Id, Pricebook2.Supply_Location_Plant__c
             FROM Contract
             WHERE Id IN :contractIds]
        );
        
        for(Sales_Contract_Line_Item__c rec : records){
            
            if(rec.Contract__c == null || rec.Plant__c == null) continue;
            
            Contract con = contractMap.get(rec.Contract__c);
            
            if(con != null && con.Pricebook2.Supply_Location_Plant__c != null){
                
                String multiPlants = con.Pricebook2.Supply_Location_Plant__c;
                
                List<String> plantList = multiPlants.split(';');
                
                if(!plantList.contains(rec.Plant__c)){
                    rec.addError('The selected Plant must match one of the Supply Location Plants defined in the associated Price Book.');
                }
            }
        }
    }
}