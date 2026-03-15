public class SAPCustomerWrapper {
    public String Customer_Code { get; set; } // Maps to "Customer" in JSON for updates
    public String Customer_Title { get; set; }
    public String Name { get; set; }
    public String Name_2 { get; set; }
    public String Search_Term1 { get; set; }
    public String Search_Term_2 { get; set; }
    public String PAN_Number { get; set; }
    public String GST_Number { get; set; }
    public String ShipTo_GST_Number { get; set; }//Added newly
    public String Telephone { get; set; }
    public String FAX_NO { get; set; }
    public String E_Mail { get; set; }
    public String Street { get; set; }
    public String City { get; set; }
    public String Postal_Code { get; set; }
    public String State { get; set; }
    public String Country { get; set; }
    public String Region { get; set; }
    public String Bank_Key { get; set; }
    public String Bank_Account_Number { get; set; }
    public String Bank_Detail_ID { get; set; }
    public String Bank_Country { get; set; }
    public String Account_Holder_Name { get; set; }
    public String Customer_Account_Group { get; set; }
    public String Sales_Organization { get; set; }
    public String Distribution_Channel { get; set; }
    public String Division { get; set; }
    public String Shipping_Conditions { get; set; }
    public String Inco_Version { get; set; }
    public String Incoterms { get; set; }
    public String Payment_Terms { get; set; }
    public String Account_Assignment_Group { get; set; }
    public String Currency_Code { get; set; } // Maps to "Currency" in JSON
    public String Reconciliation_Account { get; set; }
    public String Company_Code { get; set; }
    public String Language { get; set; }
    public String Address_Number { get; set; }
    public String Incoterms_Location { get; set; }

    // Custom method to serialize the wrapper with conditional "Customer" and "Currency" keys
    public Map<String, Object> toJsonMap() {
        Map<String, Object> jsonMap = new Map<String, Object>();
        if (Customer_Code != null) {
            jsonMap.put('Customer', Customer_Code); // Include "Customer" only if Customer_Code is not null
        }
        jsonMap.put('Customer_Title', Customer_Title);
        jsonMap.put('Name', Name);
        jsonMap.put('Name_2', Name_2);
        jsonMap.put('Search_Term1', Search_Term1);
        jsonMap.put('Search_Term_2', Search_Term_2);
        jsonMap.put('PAN_Number', PAN_Number);
        jsonMap.put('GST_Number', GST_Number);
        jsonMap.put('Telephone', Telephone);
        jsonMap.put('FAX_NO', FAX_NO);
        jsonMap.put('E_Mail', E_Mail);
        jsonMap.put('Street', Street);
        jsonMap.put('City', City);
        jsonMap.put('Postal_Code', Postal_Code);
        jsonMap.put('State', State);
        jsonMap.put('Country', Country);
        jsonMap.put('Region', Region);
        jsonMap.put('Bank_Key', Bank_Key);
        jsonMap.put('Bank_Account_Number', Bank_Account_Number);
        jsonMap.put('Bank_Detail_ID', Bank_Detail_ID);
        jsonMap.put('Bank_Country', Bank_Country);
        jsonMap.put('Account_Holder_Name', Account_Holder_Name);
        jsonMap.put('Customer_Account_Group', Customer_Account_Group);
        jsonMap.put('Sales_Organization', Sales_Organization);
        jsonMap.put('Distribution_Channel', Distribution_Channel);
        jsonMap.put('Division', Division);
        jsonMap.put('Shipping_Conditions', Shipping_Conditions);
        jsonMap.put('Inco_Version', Inco_Version);
        jsonMap.put('Incoterms', Incoterms);
        jsonMap.put('Payment_Terms', Payment_Terms);
        jsonMap.put('Account_Assignment_Group', Account_Assignment_Group);
        jsonMap.put('Currency', Currency_Code); // Map Currency_Code to "Currency"
        jsonMap.put('Reconciliation_Account', Reconciliation_Account);
        jsonMap.put('Company_Code', Company_Code);
        jsonMap.put('Language', Language);
        jsonMap.put('Address_Number', Address_Number);
        jsonMap.put('Incoterms_Location', Incoterms_Location);
        jsonMap.put('GST_Number2',ShipTo_GST_Number);
        return jsonMap;
    }
}