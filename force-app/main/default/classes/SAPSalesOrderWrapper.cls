public class SAPSalesOrderWrapper {
    public String Contract_Number { get; set; }
    public String Sales_Document_Type { get; set; }
    public String Address_Number { get; set; }
    public String Dummy_1  { get; set; }
    public String Dummy_2  { get; set; }
    
    public List<Item> Item_list { get; set; }
    public class Item {
        public String Document_Item_Number = '';
        public String Target_Quantity;
        public String Dummy_1; // Plant
        public String Dummy_2; // Ship_to_Party__c
        
        //ADDED THIS
        public List<PricingCondition> Royalty;
        
    }
    
    public class PricingCondition {
        public String Condition_type { get; set; }
        public String Amount { get; set; }
        public String Condition_Unit { get; set; }
    }
    

    public Map<String, Object> toJsonMap() {
        Map<String, Object> jsonMap = new Map<String, Object>();
        jsonMap.put('Contract_Number', Contract_Number);
        jsonMap.put('Sales_Document_Type', Sales_Document_Type);
        if (Address_Number != null) {
            jsonMap.put('Address_Number', Address_Number);
        }
        jsonMap.put('Item_list', Item_list);
        return jsonMap;
    }
}