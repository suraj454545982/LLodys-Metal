public without sharing class ProformaInvoiceController {
    public Quote quote { get; set; }
    public Opportunity opp { get; set; }
    public Account acc { get; set; }
    public Purchase_Order__c po { get; set; } 
    public Proforma_invoice__c pi { get; set; }
      public List<PILineWrapper> piLiList { get; set; }
     public Proforma_Invoice_Line_Item__c piL { get; set; }
    public Plant_Address__mdt plantAddress { get; set; }
    public String totalTaxAmountInWords {get; set;}
    public String totalAmountInWords {get; set;}
    public Decimal totalGSTAmount {get; set;}
    public String podate    {get; set;}
    public String pidate    {get; set;}
    public String quoteDate  {get; set;}
    public String paymentTermsLabel { get; set; }
    public String incoTermsLabel { get; set; }
    public String deliveryTermsLabel { get; set; }
    public String bankName{ get; set; }
    public String branchName{ get; set; }
    public String AccountNumber{ get; set; }
    

   
    
     
     /** Wrapper for PI Line Items */
    public class PILineWrapper {
        public Integer srNo { get; set; }
        public Proforma_Invoice_Line_Item__c piLine { get; set; }
        public PILineWrapper(Integer srNo, Proforma_Invoice_Line_Item__c piLine) {
            this.srNo = srNo;
            this.piLine = piLine;
        }
    }

     /** Constructor */
    public ProformaInvoiceController() {
        
         List<Company_Bank_Details__mdt> bankMeta = [
        SELECT 	Bank_Name__c,Branch_Name__c,Account_Number__c
        FROM Company_Bank_Details__mdt
        LIMIT 1
    ];

     
        bankName = (bankMeta != null && !bankMeta.isEmpty() && bankMeta[0].Bank_Name__c != null) ? bankMeta[0].Bank_Name__c : '';
        branchName = bankMeta[0].Branch_Name__c != null ? bankMeta[0].Branch_Name__c : '';
        AccountNumber = bankMeta[0].Account_Number__c != null  ? bankMeta[0].Account_Number__c : '';
        
        
    
        
        // Get Opportunity Id from page param
        Id ProformaInvoiceId = ApexPages.currentPage().getParameters().get('id');
         if (proformaInvoiceId == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Proforma Invoice Id is required.'));
            return;
        }
        
            pi  = [SELECT Id,CreatedDate,Proforma_Invoice_Number__c,Purchase_Order__c,Total_Amount_New__c,Total_Quantity_N__c,Freight__c,CGST__c,SGST__c,IGST__c,Shipping_and_Handling__c,Other_expenses__c,Packing_and_Forwarding__c,
              (SELECT id ,Quantity__c,Sales_Price__c,Invoice_Subtotal__c,
               Product__c,Product__r.Description,Product__r.ProductCode,Discount__c,Total_Amount_New__c,
               Product__r.HSN_code__c From Proforma_Invoice_Line_Items__r)
               FROM Proforma_invoice__c 
               WHERE Id =:ProformaInvoiceId 
               LIMIT 1 ]; 
        
         Date createdDateOnly = pi.CreatedDate.date();
         pidate =createdDateOnly.format(); 
        
        
         // 🔹 Build PI line wrapper list
        piLiList = new List<PILineWrapper>();
        Integer piCounter = 1;
        for (Proforma_Invoice_Line_Item__c line : pi.Proforma_Invoice_Line_Items__r) {
            piLiList.add(new PILineWrapper(piCounter, line));
            piCounter++;
        }
        
          // Fetch Purchase Order
        po = [SELECT Id,Quote__c,PO_Date__c,Name FROM Purchase_Order__c 
              WHERE Id =:pi.Purchase_Order__c  ORDER BY createdDate DESC LIMIT 1];
        podate = po.PO_Date__c.format(); 
        System.debug(po);

            // Fetch latest Approved Quote for that Opportunity
        List<Quote> fetchApprovedQuote = [
            SELECT Id, Name, BillingStreet, BillingCity, BillingState,status,
                   BillingPostalCode, BillingCountry, ShippingStreet, ShippingCity, ShippingState, 
                   ShippingPostalCode, ShippingCountry, Quote_Number__c,ExpirationDate,
                   Payment_Terms__c, Delivery_Terms__c, Delivery_Description__c,Opportunity.Account.Inco_Terms__c,
                   OpportunityId, AccountId,    Shipping_Address_Readonly__c,Shipping_Address_Readonly__City__s,Shipping_Address_Readonly__CountryCode__s,
                   Shipping_Address_Readonly__Latitude__s,Shipping_Address_Readonly__Longitude__s,Shipping_Address_Readonly__PostalCode__s,
                   Shipping_Address_Readonly__StateCode__s,Shipping_Address_Readonly__Street__s
            FROM Quote
            WHERE status = 'Accepted' AND Id = :po.Quote__c
            LIMIT 1
        ];
        system.debug(fetchApprovedQuote);
        if (fetchApprovedQuote.isEmpty()) {
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.ERROR, 'Approved Quote is required.')
            );
            return;
        }
        
         quoteDate = fetchApprovedQuote[0].ExpirationDate.format(); 

        // Assign Quote
        quote = fetchApprovedQuote[0];
        
        paymentTermsLabel = getPicklistLabel(
            'Quote',
            'Payment_Terms__c',
            quote.Payment_Terms__c
        );
        
            incoTermsLabel = getPicklistLabel(
            'Account',
            'Inco_Terms__c',
            quote.Opportunity.Account.Inco_Terms__c
        );
        
         deliveryTermsLabel = getPicklistLabel(
            'Quote',
            'Delivery_Terms__c',
            quote.Delivery_Terms__c
        );
          // Fetch related Opportunity with Plant field
        opp = [
            SELECT Id, Name, Plant_and_Shipping_Point__c 
            FROM Opportunity 
            WHERE Id = :fetchApprovedQuote[0].opportunityId
            LIMIT 1
        ];
        system.debug('opp'+opp);
  
               
         // Fetch Plant Address from CMDT
        if (opp.Plant_and_Shipping_Point__c != null) {
            List<Plant_Address__mdt> plantConfigList = [
                SELECT Dist__c, Postal_Code__c, State_Code__c, Street__c 
                FROM Plant_Address__mdt 
                WHERE MasterLabel = :opp.Plant_and_Shipping_Point__c 
                LIMIT 1
            ];
            system.debug('plantConfigList'+plantConfigList);
       plantAddress = plantConfigList[0];
        }
    
        
                    totalGSTAmount = pi.Freight__c+pi.CGST__c+pi.SGST__c+pi.IGST__c+pi.Shipping_and_Handling__c+pi.Packing_and_Forwarding__c+pi.Other_expenses__c;
        
                    // Convert amounts to words
                    totalTaxAmountInWords = convertNumberToWords(totalGSTAmount);
                    totalAmountInWords = convertNumberToWords(pi.Total_Amount_New__c);
        

       
         
        
        
    }
    
    public static String getPicklistLabel(String objectName, String fieldName, String fieldValue) {
    if (String.isBlank(fieldValue)) {
        return '';
    }

    Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
    Schema.DescribeFieldResult fieldDesc = objType.getDescribe()
        .fields.getMap().get(fieldName).getDescribe();

    for (Schema.PicklistEntry ple : fieldDesc.getPicklistValues()) {
        if (ple.getValue() == fieldValue) {
            return ple.getLabel(); // ✅ returns "Suraj"
        }
    }
    return fieldValue; // fallback
}

    
    
    
    
      // Helper method to convert number to words (Indian numbering system)
    Public String convertNumberToWords(Decimal amount) {
        if (amount == null || amount == 0) {
            return 'Zero Rupees Only';
        }
        
        // Split the number into integer and decimal parts
        String amountStr = String.valueOf(amount.setScale(2));
        List<String> parts = amountStr.split('\\.');
        Integer intPart = Integer.valueOf(parts[0]);
        Integer decPart = parts.size() > 1 ? Integer.valueOf(parts[1]) : 0;
        
        String words = '';
        
        // Process integer part
        if (intPart > 0) {
            words = convertIntegerToWords(intPart) + ' Rupees';
        }
        
        // Process decimal part
        if (decPart > 0) {
            if (words != '') {
                words += ' and ';
            }
            words += convertIntegerToWords(decPart) + ' Paise';
        }
        
        return words + ' Only';
    }
    
        private String convertIntegerToWords(Integer num) {
        // Arrays for digit words
        String[] units = new String[] {
            '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
                'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 
                'Eighteen', 'Nineteen'
                };
                    
                    String[] tens = new String[] {
                        '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
                            };
                                
                                if (num == 0) {
                                    return '';
                                }
        
        if (num < 20) {
            return units[num];
        }
        
        if (num < 100) {
            Integer tensDigit = num / 10;
            Integer unitsDigit = num - (tensDigit * 10);
            return tens[tensDigit] + (unitsDigit > 0 ? ' ' + units[unitsDigit] : '');
        }
        
        if (num < 1000) {
            Integer hundredsDigit = num / 100;
            Integer remainder = num - (hundredsDigit * 100);
            return units[hundredsDigit] + ' Hundred' + (remainder > 0 ? ' ' + convertIntegerToWords(remainder) : '');
        }
        
        if (num < 100000) {
            Integer thousandsDigit = num / 1000;
            Integer remainder = num - (thousandsDigit * 1000);
            return convertIntegerToWords(thousandsDigit) + ' Thousand' + (remainder > 0 ? ' ' + convertIntegerToWords(remainder) : '');
        }
        
        if (num < 10000000) {
            Integer lakhsDigit = num / 100000;
            Integer remainder = num - (lakhsDigit * 100000);
            return convertIntegerToWords(lakhsDigit) + ' Lakh' + (remainder > 0 ? ' ' + convertIntegerToWords(remainder) : '');
        }
        
        Integer croresDigit = num / 10000000;
        Integer remainder = num - (croresDigit * 10000000);
        return convertIntegerToWords(croresDigit) + ' Crore' + (remainder > 0 ? ' ' + convertIntegerToWords(remainder) : '');
    }
    
    
}