public class SAPSalesOrderUpdateWrapper {
    public String Sale_Order_Number { get; set; }
    public String Address_Number { get; set; }
    public String Dummy1 { get; set; }
    public String Dummy2 { get; set; }
    public List<Item> SalesOrderUpdate_item_list { get; set; }

    public SAPSalesOrderUpdateWrapper() {
        SalesOrderUpdate_item_list = new List<Item>();
    }

    public class Item {
        public String Item;              // Maps to OrderItem.Quantity
        public String Material;         // Maps to OrderItem.Product_Code__c
        public String Reason_for_Rejection; // Maps to OrderItem.Reason_for_Rejection__c
        public String Qty ;
        public String Plant ;
        public String Dummy1;
        public String Dummy2;
    }

    public Map<String, Object> toJsonMap() {
        Map<String, Object> jsonMap = new Map<String, Object>();
        jsonMap.put('Sale_Order_Number', Sale_Order_Number);
        jsonMap.put('Address_Number', Address_Number);
        jsonMap.put('Dummy1', Dummy1);
        jsonMap.put('Dummy2', Dummy2);
        jsonMap.put('SalesOrderUpdate_item_list', SalesOrderUpdate_item_list);
        return jsonMap;
    }
}