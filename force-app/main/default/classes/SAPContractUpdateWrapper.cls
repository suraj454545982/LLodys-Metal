public class SAPContractUpdateWrapper {
    public String Contract_Number { get; set; }
    public List<UpdateItem> SalesContractUpdate_item_list { get; set; }

    public class UpdateItem {
        public String Item { get; set; }
        public String Material { get; set; }
        public String Reason_for_Rejection { get; set; }
    }

    // Serialization method for Update payload
    public Map<String, Object> toJsonMap() {
        Map<String, Object> jsonMap = new Map<String, Object>();
        jsonMap.put('Contract_Number', Contract_Number);

        if (SalesContractUpdate_item_list != null && !SalesContractUpdate_item_list.isEmpty()) {
            List<Map<String, Object>> updateItemsList = new List<Map<String, Object>>();
            for (UpdateItem ui : SalesContractUpdate_item_list) {
                Map<String, Object> uiMap = new Map<String, Object>();
                uiMap.put('Item', ui.Item);
                uiMap.put('Material', ui.Material);
                uiMap.put('Reason_for_Rejection', ui.Reason_for_Rejection);
                updateItemsList.add(uiMap);
            }
            jsonMap.put('SalesContractUpdate_item_list', updateItemsList);
        }

        return jsonMap;
    }
}