public class SAPContractWrapper {
    public String Contract_Type { get; set; }
    public String SH_address_No { get; set; } //Added Newly 14/02/2025
    public String Ship_to_Party { get; set; }
    public String Sold_to_Party { get; set; }
    public String Sales_Organization { get; set; }
    public String Distribution_Channel { get; set; }
    public String Division { get; set; }
    public String Customer_Reference { get; set; }
    public String Cust_Ref_Date { get; set; }
    public String Valid_From { get; set; }
    public String Valid_To { get; set; }
    public String Pricing_Date { get; set; }
    
    //Newly Added in API
    public String Incoterms { get; set; }
    public String Payment_Terms { get; set; }
    public String Quotation_Number { get; set; }
    public String Salesforce_Contract_Id { get; set; }
    public String Incolocation { get; set; }
    
    public List<HeaderText> Header_Texts { get; set; }
    public List<ContractItem> Contract_item_list { get; set; }

    // Inner Classes
    public class HeaderText {
        public String Text_ID { get; set; }
        public String Text { get; set; }
    }

    public class ContractItem {
        public String Product_Number { get; set; }
        public String Contract_Document_Item_Number { get; set; }
        public String Target_quantity { get; set; }
        public String Unit_of_Measure { get; set; }
        public String Currency_Code { get; set; } // Maps to 'Currency' in JSON
        public String Plant { get; set; }
        public String Profit_Center { get; set; }
        public List<LineitemText> Lineitem_Texts { get; set; }
        public List<PricingCondition> Pricing_Conditions { get; set; }
        public String Condition_Pricing_Unit { get; set; }
        public String Condition_Unit_of_Measure { get; set; }
        public String Partner_Function { get; set; }
        public String Customer_Number { get; set; }
    }

    public class LineitemText {
        public String Text_ID { get; set; }
        public String Text { get; set; }
    }

    public class PricingCondition {
        public String Condition_type { get; set; }
        public String Amount { get; set; }
        public String Condition_Unit { get; set; }
    }

    // Utility: Escape special characters in text from TextArea
    private static String sanitizeText(String input) {
        if (input == null) return null;
        return input
            .replace('\\', '\\\\')   // Backslash first!
            .replace('"', '\\"')     // Double quotes
            .replace('\r\n', '\\n')  // Windows newlines
            .replace('\n', '\\n')    // Unix newlines
            .replace('\r', '\\n')    // Old Mac newlines
            .replace('\t', '\\t');   // Tabs
    }

    // Convert to JSON-compatible Map with sanitized text
    public Map<String, Object> toJsonMap() {
        Map<String, Object> jsonMap = new Map<String, Object>();
        
        jsonMap.put('Contract_Type', Contract_Type);
        jsonMap.put('SH_address_No', SH_address_No);//Added Newly 14/02/2025
        jsonMap.put('Ship_to_Party', Ship_to_Party);
        jsonMap.put('Sold_to_Party', Sold_to_Party);
        jsonMap.put('Sales_Organization', Sales_Organization);
        jsonMap.put('Distribution_Channel', Distribution_Channel);
        jsonMap.put('Division', Division);
        jsonMap.put('Customer_Reference', Customer_Reference);
        jsonMap.put('Cust_Ref_Date', Cust_Ref_Date);
        jsonMap.put('Valid_From', Valid_From);
        jsonMap.put('Valid_To', Valid_To);
        jsonMap.put('Pricing_Date', Pricing_Date);
        //newly added
        jsonMap.put('incoterms', Incoterms);
        jsonMap.put('payment_terms', Payment_Terms);
        jsonMap.put('Quotation_no', Quotation_Number);
        jsonMap.put('EXT_Contract_Number', Salesforce_Contract_Id);
        jsonMap.put('Incolocation', Incolocation);

        // Header Texts
        if (Header_Texts != null) {
            List<Map<String, Object>> headerTextsList = new List<Map<String, Object>>();
            for (HeaderText ht : Header_Texts) {
                Map<String, Object> htMap = new Map<String, Object>();
                htMap.put('Text_ID', ht.Text_ID);
                htMap.put('Text', sanitizeText(ht.Text)); // SANITIZED
                headerTextsList.add(htMap);
            }
            jsonMap.put('Header_Texts', headerTextsList);
        }

        // Contract Items
        if (Contract_item_list != null) {
            List<Map<String, Object>> contractItemsList = new List<Map<String, Object>>();
            for (ContractItem ci : Contract_item_list) {
                Map<String, Object> ciMap = new Map<String, Object>();
                ciMap.put('Product_Number', ci.Product_Number);
                ciMap.put('Contract_Document_Item_Number', ci.Contract_Document_Item_Number);
                ciMap.put('Target_quantity', ci.Target_quantity);
                ciMap.put('Unit_of_Measure', ci.Unit_of_Measure);
                ciMap.put('Currency', ci.Currency_Code); // Maps to 'Currency'
                ciMap.put('Plant', ci.Plant);
                ciMap.put('Profit_Center', ci.Profit_Center);
                ciMap.put('Condition_Pricing_Unit', ci.Condition_Pricing_Unit);
                ciMap.put('Condition_Unit_of_Measure', ci.Condition_Unit_of_Measure);
                ciMap.put('Partner_Function', ci.Partner_Function);
                ciMap.put('Customer_Number', ci.Customer_Number);

                // Lineitem Texts
                if (ci.Lineitem_Texts != null) {
                    List<Map<String, Object>> lineitemTextsList = new List<Map<String, Object>>();
                    for (LineitemText lt : ci.Lineitem_Texts) {
                        Map<String, Object> ltMap = new Map<String, Object>();
                        ltMap.put('Text_ID', lt.Text_ID);
                        ltMap.put('Text', sanitizeText(lt.Text)); // SANITIZED
                        lineitemTextsList.add(ltMap);
                    }
                    ciMap.put('Lineitem_Texts', lineitemTextsList);
                }

                // Pricing Conditions (NO sanitization - safe)
                if (ci.Pricing_Conditions != null) {
                    List<Map<String, Object>> pricingConditionsList = new List<Map<String, Object>>();
                    for (PricingCondition pc : ci.Pricing_Conditions) {
                        Map<String, Object> pcMap = new Map<String, Object>();
                        pcMap.put('Condition_type', pc.Condition_type);
                        pcMap.put('Amount', pc.Amount);
                        pcMap.put('Condition_Unit', pc.Condition_Unit);
                        pricingConditionsList.add(pcMap);
                    }
                    ciMap.put('Pricing_Conditions', pricingConditionsList);
                }

                contractItemsList.add(ciMap);
            }
            jsonMap.put('Contract_item_list', contractItemsList);
        }

        return jsonMap;
    }

    // Final JSON output (compact)
    public String toOrderedJson() {
        return JSON.serialize(this.toJsonMap());
    }

    // Optional: Pretty-printed JSON for debugging
    public String toOrderedJsonPretty() {
        return JSON.serializePretty(this.toJsonMap());
    }

    // Format Date as dd.MM.yyyy
    public static String formatDate(Date d) {
        if (d == null) return '';
        String day = String.valueOf(d.day()).leftPad(2, '0');
        String month = String.valueOf(d.month()).leftPad(2, '0');
        String year = String.valueOf(d.year());
        return day + '.' + month + '.' + year;
    }
   
}