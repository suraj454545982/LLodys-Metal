public with sharing class PricingConditionController {
    
    // Building Pricing Condition from Quote and Quote Line Item
    public static String buildPricingConditionsFromPO(
        Id purchaseOrderId,
        Decimal unitPrice,
        Decimal gstPercentage,
        PricebookEntry pbe,
        String currencyIsoCode
    ) {
        if (purchaseOrderId == null) return null;
        
        // Get Quote via PO (single source of truth)
        Purchase_Order__c po = [
            SELECT Quote__c
            FROM Purchase_Order__c
            WHERE Id = :purchaseOrderId
            LIMIT 1
        ];
        
        if (po.Quote__c == null) return null;
        
        // Get Billing & Shipping State from Quote
        Quote qt = [
            SELECT BillingState, ShippingState,BillingStateCode,
            Shipping_Address_Lookup__c,
            Shipping_Address_Lookup__r.Shipping_Address__StateCode__s
            FROM Quote
            WHERE Id = :po.Quote__c
            LIMIT 1
        ];
        
        List<Map<String, Object>> pricingList = new List<Map<String, Object>>();
        
        // ───────────────
        // PR00 – Base Price
        // ───────────────
        if (unitPrice != null) {
            pricingList.add(new Map<String, Object>{
                'Condition_type' => 'PR00',
                    'Amount'         => String.valueOf(unitPrice),
                    'Condition_Unit' => currencyIsoCode,
                    'Locked' => true
                    });
        }
        
        // ───────────────
        // GST CONDITIONS
        // ───────────────
        if (gstPercentage != null && gstPercentage > 0) {
            String shipStateCode =
                qt.Shipping_Address_Lookup__r != null
                ? qt.Shipping_Address_Lookup__r.Shipping_Address__StateCode__s
                : null;
            
            if (qt.BillingStateCode == shipStateCode) { 
                Decimal halfGst = gstPercentage / 2;
                
                pricingList.add(new Map<String, Object>{
                    'Condition_type' => 'JOCG',
                        'Amount'         => String.valueOf(halfGst),
                        'Condition_Unit' => ''
                        });
                
                pricingList.add(new Map<String, Object>{
                    'Condition_type' => 'JOSG',
                        'Amount'         => String.valueOf(halfGst),
                        'Condition_Unit' => ''
                        });
                
            } else {
                pricingList.add(new Map<String, Object>{
                    'Condition_type' => 'JOIG',
                        'Amount'         => String.valueOf(gstPercentage),
                        'Condition_Unit' => ''
                        });
            }
        }
        
        // ───────────────
        // PRICEBOOK ENTRY CONDITIONS
        // ───────────────
        if (pbe != null) {
            
            if (pbe.Freight__c != null && pbe.Freight__c > 0) {
                pricingList.add(new Map<String, Object>{
                    'Condition_type' => 'ZFRT',
                        'Amount'         => String.valueOf(pbe.Freight__c),
                        'Condition_Unit' => currencyIsoCode,
                        'Locked' => true   // ONLY here Because it is coming from PBE
                        });
            }
            
            if (pbe.Royalty__c != null && pbe.Royalty__c > 0) {
                pricingList.add(new Map<String, Object>{
                    'Condition_type' => 'ZRYL',
                        'Amount'         => String.valueOf(pbe.Royalty__c),
                        'Condition_Unit' => currencyIsoCode
                        });
            }
            
            if (pbe.DMT_and_other_taxes__c != null && pbe.DMT_and_other_taxes__c > 0) {
                pricingList.add(new Map<String, Object>{
                    'Condition_type' => 'ZDMT',
                        'Amount'         => String.valueOf(pbe.DMT_and_other_taxes__c),
                        'Condition_Unit' => currencyIsoCode
                        });
            }
        }
        
        // Wrap JSON
        return JSON.serialize(new Map<String, Object>{
            'Pricing_Conditions' => pricingList
                });
    }
    
    public static void rebuildPricingConditionsForCLIs(
        List<Sales_Contract_Line_Item__c> clis,
        Quote quoteRec
    ) {
        if (clis == null || clis.isEmpty() || quoteRec == null) return;
        
        for (Sales_Contract_Line_Item__c cli : clis) {
            
            List<Map<String, Object>> pricingList = new List<Map<String, Object>>();
            
            // Unit Price → PR00
            if (cli.List_Price__c != null) {
                pricingList.add(new Map<String, Object>{
                    'Condition_type' => 'PR00',
                        'Amount'         => String.valueOf(cli.List_Price__c),
                        'Condition_Unit' => cli.CurrencyIsoCode,
                        'Locked' => true //Added Newly to Lock the PR00
                        });
            }
            
            // GST Logic
            Decimal gst = cli.GST_Tax_Percentage__c;
            
            if (gst != null && gst > 0) {
                
                String shipState =
                    quoteRec.Shipping_Address_Lookup__r != null
                    ? quoteRec.Shipping_Address_Lookup__r.Shipping_Address__StateCode__s
                    : null;
                
                // Same State → CGST + SGST
                if (quoteRec.BillingStateCode == shipState) {
                    Decimal halfGst = gst / 2;
                    
                    pricingList.add(new Map<String, Object>{
                        'Condition_type' => 'JOCG',
                            'Amount'         => String.valueOf(halfGst),
                            'Condition_Unit' => ''
                            });
                    
                    pricingList.add(new Map<String, Object>{
                        'Condition_type' => 'JOSG',
                            'Amount'         => String.valueOf(halfGst),
                            'Condition_Unit' => ''
                            });
                }
                // Different State → IGST
                else {
                    pricingList.add(new Map<String, Object>{
                        'Condition_type' => 'JOIG',
                            'Amount'         => String.valueOf(gst),
                            'Condition_Unit' => ''
                            });
                }
            }
            
            // Wrap JSON
            Map<String, Object> wrapper = new Map<String, Object>{
                'Pricing_Conditions' => pricingList
                    };
                        
                        cli.Pricing_Conditions__c = JSON.serialize(wrapper);
        }
    }
    
    public static void rebuildPricingFromQLI(Sales_Contract_Line_Item__c cli,Quote quoteRec,QuoteLineItem qli) {
        if (cli == null || quoteRec == null || qli == null) return;
        
        List<Map<String, Object>> pricingList = new List<Map<String, Object>>();
        
        // Base Price from QLI
        if (qli.UnitPrice != null) {
            pricingList.add(new Map<String, Object>{
                'Condition_type' => 'PR00',
                    'Amount'         => String.valueOf(qli.UnitPrice),
                    'Condition_Unit' => cli.CurrencyIsoCode,
                    'Locked' => true //Added Newly to Lock the PR00
                    });
        }
        
        // GST logic from QLI
        Decimal gst = qli.GST_Tax_Percentage__c;
        
        if (gst != null && gst > 0) {
            if (quoteRec.BillingStateCode == quoteRec.Shipping_Address_Lookup__r.Shipping_Address__StateCode__s) {
                Decimal halfGst = gst / 2;
                
                pricingList.add(new Map<String, Object>{
                    'Condition_type' => 'JOCG',
                        'Amount'         => String.valueOf(halfGst),
                        'Condition_Unit' => ''
                        });
                
                pricingList.add(new Map<String, Object>{
                    'Condition_type' => 'JOSG',
                        'Amount'         => String.valueOf(halfGst),
                        'Condition_Unit' => ''
                        });
                
            } else {
                pricingList.add(new Map<String, Object>{
                    'Condition_type' => 'JOIG',
                        'Amount'         => String.valueOf(gst),
                        'Condition_Unit' => ''
                        });
            }
        }
        
        cli.Pricing_Conditions__c = JSON.serialize(
            new Map<String, Object>{
                'Pricing_Conditions' => pricingList
                    }
        );
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPricingConditions(Id recordId) {
        try {
            Sales_Contract_Line_Item__c cli = [
                SELECT Pricing_Conditions__c, CurrencyIsoCode
                FROM Sales_Contract_Line_Item__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            Map<String, Object> result = new Map<String, Object>();
            result.put('Currency', cli.CurrencyIsoCode != null ? cli.CurrencyIsoCode : '');
            
            if (String.isNotBlank(cli.Pricing_Conditions__c)) {
                result.put(
                    'Pricing_Conditions',
                    ((Map<String, Object>) JSON.deserializeUntyped(cli.Pricing_Conditions__c))
                    .get('Pricing_Conditions')
                );
            } else {
                result.put('Pricing_Conditions', new List<Object>());
            }
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error retrieving pricing conditions: ' + e.getMessage()
            );
        }
    }
    
    @AuraEnabled
    public static void savePricingConditions(Id recordId,String pricingConditions) {
        try {
            // 1. Get the Contract Line Item and its Parent Contract
            Sales_Contract_Line_Item__c cliRec = [
                SELECT Id,
                Contract__c,
                Contract__r.ContractApprovalStatus__c
                FROM Sales_Contract_Line_Item__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            // 2. Check Parent Contract Approval Status
            if (cliRec.Contract__r.ContractApprovalStatus__c == 'Approved') {
                throw new AuraHandledException(
                    'This Contract is freezed, you cannot edit because this Contract is Approved.'
                );
            }
            
            // 3. If not approved → proceed with update
            Sales_Contract_Line_Item__c cli = new Sales_Contract_Line_Item__c(
                Id = recordId,
                Pricing_Conditions__c = pricingConditions
            );
            
            //This Snippet is used to Restrict Deleting PR00 and ZFRT which is coming from Quote and PBE
            /** START **/
            // ===============================
            // PROTECT SYSTEM LOCKED CONDITIONS
            // ===============================
            
            // Load existing stored JSON
            Sales_Contract_Line_Item__c oldCli = [
                SELECT Pricing_Conditions__c
                FROM Sales_Contract_Line_Item__c
                WHERE Id = :recordId
            ];
            
            // Parse OLD JSON
            Map<String,Object> oldParsed =
                String.isNotBlank(oldCli.Pricing_Conditions__c)
                ? (Map<String,Object>)JSON.deserializeUntyped(oldCli.Pricing_Conditions__c)
                : new Map<String,Object>();
            
            List<Object> oldRows =
                (List<Object>)oldParsed.get('Pricing_Conditions');
            
            // Parse NEW JSON from UI
            Map<String,Object> newParsed =
                (Map<String,Object>)JSON.deserializeUntyped(pricingConditions);
            
            List<Object> newRows =
                (List<Object>)newParsed.get('Pricing_Conditions');
            
            // Build map of locked rows from OLD data
            Map<String,Map<String,Object>> lockedSystem = new Map<String,Map<String,Object>>();
            
            if(oldRows != null){
                for(Object o : oldRows){
                    
                    Map<String,Object> r = (Map<String,Object>)o;
                    
                    Boolean locked =
                        r.containsKey('Locked') ? (Boolean)r.get('Locked') : false;
                    
                    if(locked){
                        lockedSystem.put((String)r.get('Condition_type'), r);
                    }
                }
            }
            
            // Validate NEW rows against OLD locked rows
            for(String cond : lockedSystem.keySet()){
                
                Boolean found = false;
                
                if(newRows != null){
                    for(Object o : newRows){
                        
                        Map<String,Object> r = (Map<String,Object>)o;
                        
                        if(cond == (String)r.get('Condition_type')){
                            
                            found = true;
                            
                            // compare amount
                            if(String.valueOf(r.get('Amount')) !=
                               String.valueOf(lockedSystem.get(cond).get('Amount'))){
                                   
                                   throw new AuraHandledException(
                                       'System pricing conditions cannot be modified.'
                                   );
                               }
                        }
                    }
                }
                
                // user deleted locked row
                if(!found){
                    throw new AuraHandledException(
                        'Base Price or Freight from Quote or Pricebook Entry respectively cannot be removed.'
                    );
                }
            }
            /** END **/
            
            update cli;
            
        } catch (AuraHandledException ahe) {
            throw ahe;
            
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error saving pricing conditions: ' + e.getMessage()
            );
        }
    }
    
    // Extending Pricing Condition Controller for OrderItem
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getOrderItemPricing(Id recordId) {
        
        OrderItem oi = [
            SELECT Pricing_Condition__c,
            Order.CurrencyIsoCode
            FROM OrderItem
            WHERE Id = :recordId
            LIMIT 1
        ];
        
        Map<String, Object> result = new Map<String, Object>();
        
        String currencyIso =
            oi.Order != null ? oi.Order.CurrencyIsoCode : '';
        
        result.put('Currency', currencyIso);
        
        if (String.isNotBlank(oi.Pricing_Condition__c)) {
            
            Map<String, Object> parsed =
                (Map<String, Object>)
                JSON.deserializeUntyped(oi.Pricing_Condition__c);
            
            // IMPORTANT: use plural key
            result.put(
                'Pricing_Conditions',
                parsed.get('Pricing_Conditions')
            );
            
        } else {
            result.put('Pricing_Conditions', new List<Object>());
        }
        
        return result;
    }
    
    
    @AuraEnabled
    public static void saveOrderItemPricing(Id recordId,String pricingConditions) {
        OrderItem oi = new OrderItem(
            Id = recordId,
            Pricing_Condition__c = pricingConditions
        );
        
        update oi;
    }
    
    public static String filterPricingConditions(String pricingJson) {
        
        if(String.isBlank(pricingJson)) return pricingJson;
        
        Map<String,Object> parsed =
            (Map<String,Object>)JSON.deserializeUntyped(pricingJson);
        
        List<Object> original =
            (List<Object>)parsed.get('Pricing_Conditions');
        
        if(original == null) return pricingJson;
        
        Set<String> allowed = new Set<String>{
            'ZRYL','ZDMF','ZNMT'
                };
                    
                    List<Object> filtered = new List<Object>();
        
        for(Object o : original){
            
            Map<String,Object> row = (Map<String,Object>)o;
            
            String type = (String)row.get('Condition_type');
            
            if(allowed.contains(type)){
                filtered.add(row);
            }
        }
        
        parsed.put('Pricing_Conditions', filtered);
        
        return JSON.serialize(parsed);
    }
    
    
}