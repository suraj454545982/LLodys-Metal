/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 07-02-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/


public without Sharing class OfferLetterControllerExtension {
    public Quote quote;
    public List<QuoteLineItemWrapper> quoteLineItemWrappers {get; set;}
    public Decimal centralGST {get; set;}
    public Decimal stateGST {get; set;}
    public Decimal totalGSTAmount {get; set;}
    public String totalTaxAmountInWords {get; set;}
    public String totalAmountInWords {get; set;}
    public String paymentTermsLabel { get; set; }
    public String deliveryTermsLabel { get; set; }
    public String billingStateCode { get; private set; }
    public String billingStateName { get; private set; }
    public String shippingStateCode { get; private set; }
    public String shippingStateName { get; private set; }
    public String category { get; set; }
    public List<QuoteLineItem> quoteLineItems { get; set; }
    
    private static final Map<String, String> stateCodeMap = new Map<String, String>{
        'Andhra Pradesh' => '37', 'Arunachal Pradesh' => '12', 'Assam' => '18',
            'Bihar' => '10', 'Chhattisgarh' => '22', 'Goa' => '30',
            'Gujarat' => '24', 'Haryana' => '06', 'Himachal Pradesh' => '02',
            'Jharkhand' => '20', 'Karnataka' => '29', 'Kerala' => '32',
            'Madhya Pradesh' => '23', 'Maharashtra' => '27', 'Manipur' => '14',
            'Meghalaya' => '17', 'Mizoram' => '15', 'Nagaland' => '13',
            'Odisha' => '21', 'Punjab' => '03', 'Rajasthan' => '08',
            'Sikkim' => '11', 'Tamil Nadu' => '33', 'Telangana' => '36',
            'Tripura' => '16', 'Uttar Pradesh' => '09', 'Uttarakhand' => '05',
            'West Bengal' => '19', 'Delhi' => '07', 'Jammu and Kashmir' => '01',
            'Ladakh' => '38', 'Puducherry' => '34', 'Andaman and Nicobar Islands' => '35',
            'Chandigarh' => '04', 'Dadra and Nagar Haveli and Daman and Diu' => '26',
            'Lakshadweep' => '31'
            };
                private static final Map<String, String> stateAbbreviationMap = new Map<String, String>{
                    'AP' => 'Andhra Pradesh', 'AR' => 'Arunachal Pradesh', 'AS' => 'Assam',
                        'BR' => 'Bihar', 'CG' => 'Chhattisgarh', 'GA' => 'Goa',
                        'GJ' => 'Gujarat', 'HR' => 'Haryana', 'HP' => 'Himachal Pradesh',
                        'JH' => 'Jharkhand', 'KA' => 'Karnataka', 'KL' => 'Kerala',
                        'MP' => 'Madhya Pradesh', 'MH' => 'Maharashtra', 'MN' => 'Manipur',
                        'ML' => 'Meghalaya', 'MZ' => 'Mizoram', 'NL' => 'Nagaland',
                        'OD' => 'Odisha', 'PB' => 'Punjab', 'RJ' => 'Rajasthan',
                        'SK' => 'Sikkim', 'TN' => 'Tamil Nadu', 'TG' => 'Telangana',
                        'TR' => 'Tripura', 'UP' => 'Uttar Pradesh', 'UK' => 'Uttarakhand',
                        'WB' => 'West Bengal', 'DL' => 'Delhi', 'JK' => 'Jammu and Kashmir',
                        'LA' => 'Ladakh', 'PY' => 'Puducherry', 'AN' => 'Andaman and Nicobar Islands',
                        'CH' => 'Chandigarh', 'DN' => 'Dadra and Nagar Haveli and Daman and Diu', 'LD' => 'Lakshadweep'
                        };
                            
                            // Method to get state code from abbreviation or full name
                            private String getStateCode(String state) {
                                if (String.isBlank(state)) return '';
                                
                                state = state.trim();
                                
                                // Direct match in state code map (full state names)
                                if (stateCodeMap.containsKey(state)) {
                                    return stateCodeMap.get(state);
                                }
                                
                                // Check if it's a state abbreviation
                                if (stateAbbreviationMap.containsKey(state)) {
                                    String fullStateName = stateAbbreviationMap.get(state);
                                    return stateCodeMap.get(fullStateName);
                                }
                                
                                return ''; // Return empty if no match found
                            }
    
    // Method to get full state name from abbreviation
    private String getFullStateName(String state) {
        if (String.isBlank(state)) return '';
        
        state = state.trim();
        
        // Direct match in state code map (already a full state name)
        if (stateCodeMap.containsKey(state)) {
            return state;
        }
        
        // Check if it's a state abbreviation
        if (stateAbbreviationMap.containsKey(state)) {
            return stateAbbreviationMap.get(state);
        }
        
        return state; // Return original if no match found
    }
    
    // Wrapper class for QuoteLineItem with serial number
    public class QuoteLineItemWrapper {
        public QuoteLineItem lineItem {get; set;}
        public Integer serialNumber {get; set;}
        public QuoteLineItemWrapper(QuoteLineItem lineItem, Integer serialNumber) {
            this.lineItem = lineItem;
            this.serialNumber = serialNumber;
        }
    }
    
    public OfferLetterControllerExtension(ApexPages.StandardController stdController) {
        // Get quote from StandardController
        this.quote = (Quote)stdController.getRecord();
        
        // Check for quoteId in URL parameters
        String quoteIdFromUrl = ApexPages.currentPage().getParameters().get('quoteId');
        
        // Use URL parameter if available, otherwise fall back to StandardController
        String quoteId = String.isNotBlank(quoteIdFromUrl) ? quoteIdFromUrl : (this.quote != null ? this.quote.Id : null);
            
            if (String.isNotBlank(quoteId) && quoteId instanceOf Id) {
                try {
                    // Query the Quote with necessary fields
                    this.quote = [
                        SELECT Id, Name, Quote_Number__c, CreatedDate, opportunity.category__c,Quote_Grand_Total__c,
                        Account.Name, Account.BillingStreet, Account.BillingCity, Account.BillingState, Account.BillingPostalCode,
                        Account.ShippingStreet, Account.ShippingCity, Account.ShippingState, Account.ShippingPostalCode,
                        Account.GST_No__c, Account.PAN__c,CentralGST__c,StateGST__c,Shipping_and_Handling_Rollup__c,
                        Delivery_Terms__c, Payment_Terms__c,Freight__c,Packing_and_Forwarding_Rollup__c,
                        BillingName,shippingname,Other_expenses_Rollup__c,CGST__c,IGST__c,SGST__c,subtotal,
                        BillingStreet, BillingCity, BillingState, BillingPostalCode,
                        ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, 
                        GrandTotal,More_Payment_Terms__c,Tolerances__c,More_delivery_Terms__c,Additional_Terms_and_Condition__c,
                        Delivery_Description__c,Description,ExpirationDate,Email,Phone,Technical_Specifications__c,IBM__c,
                        Shipping_Address_Readonly__c,Shipping_Address_Readonly__City__s,Shipping_Address_Readonly__CountryCode__s,
                        Shipping_Address_Readonly__Latitude__s,Shipping_Address_Readonly__Longitude__s,Shipping_Address_Readonly__PostalCode__s,
                        Shipping_Address_Readonly__StateCode__s,Shipping_Address_Readonly__Street__s,
                        Account.Shipping_Address_readonly__Street__s,Account.Shipping_Address_readonly__City__s,Account.Shipping_Address_readonly__PostalCode__s
                        FROM Quote 
                        WHERE Id = :quoteId
                        LIMIT 1
                    ];
                    category = quote.Opportunity.Category__c;
                    //StateCode
                    String billingState = '';
                    if (!String.isBlank(quote.BillingState)) {
                        billingState = quote.BillingState;
                    } else if (!String.isBlank(quote.Account.BillingState)) {
                        billingState = quote.Account.BillingState;
                    }
                    
                    String shippingState = '';
                    if (!String.isBlank(quote.Shipping_Address_Readonly__StateCode__s)) {
                        shippingState = quote.Shipping_Address_Readonly__StateCode__s;
                    } else if (!String.isBlank(quote.Account.Shipping_Address_Readonly__StateCode__s)) {
                        shippingState = quote.Account.Shipping_Address_Readonly__StateCode__s;
                    }
                    
                    
                    
                    // Set state codes and full names
                    billingStateCode = getStateCode(billingState);
                    billingStateName = getFullStateName(billingState);
                    shippingStateCode = getStateCode(shippingState);
                    shippingStateName = getFullStateName(shippingState);
                    // Payment Terms Label
                    paymentTermsLabel = getPicklistLabel('Quote', 'Payment_Terms__c', quote.Payment_Terms__c);
                    deliveryTermsLabel = getPicklistLabel('Quote', 'Delivery_Terms__c', quote.Delivery_Terms__c);
                    // Query Quote Line Items
                    this.quoteLineItems = [
                        SELECT Id, Product2.Name, Product2.ProductCode,product2.HSN_code__c,Total_Price_Custom__c,Subtotal ,
                        Product2.QuantityUnitOfMeasure, Quantity, UnitPrice, TotalPrice,Product2.Description
                        FROM QuoteLineItem 
                        WHERE QuoteId = :quoteId
                    ];
                    
                    // Populate wrappers with serial numbers
                    quoteLineItemWrappers = new List<QuoteLineItemWrapper>();
                    Integer serialNumber = 1;
                    for (QuoteLineItem lineItem : quoteLineItems) {
                        quoteLineItemWrappers.add(new QuoteLineItemWrapper(lineItem, serialNumber));
                        serialNumber++;
                    }
                    
                    // Calculate GST amounts (assuming 9% CGST and 9% SGST)
                    if(quote.IGST__c==null || quote.IGST__c == 0){
                        centralGST = quote.CGST__c;
                    stateGST = quote.SGST__c; 
                    }else{
                        centralGST = quote.IGST__c/2;
                    stateGST = quote.IGST__c/2;  
                    }
                   
                    totalGSTAmount = centralGST + stateGST;
                    
                    // Convert amounts to words
                    totalTaxAmountInWords = convertNumberToWords(totalGSTAmount);
                    totalAmountInWords = convertNumberToWords(quote.Quote_Grand_Total__c);
                } catch (Exception e) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Invalid Quote ID or data not found: ' + e.getMessage()));
                }
            } else {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Quote ID is missing or invalid.'));
            }
    }
    
    
    
    
    public static String getPicklistLabel(String objectName, String fieldName, String value) {
        if (value == null) return null;
        
        String label = value; // Default to the value if label not found
        
        // Get the describe result for the field
        Schema.DescribeFieldResult fieldDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap().get(fieldName).getDescribe();
        
        // Loop through picklist entries to find matching value
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (entry.getValue() == value) {
                label = entry.getLabel();
                break;
            }
        }
        
        return label;
    }
    public Quote getQuote() {
        return this.quote;
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
    
            
@AuraEnabled
public static String saveAndEmailPDF(String quoteId) {
    if (String.isBlank(quoteId)) {
        return JSON.serialize(new Map<String, String>{'error' => 'Quote ID is required.'});
    }

    try {
        List<ProcessInstanceWorkitem> activeWorkItems = [
            SELECT Id
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId = :quoteId
        ];
        if (!activeWorkItems.isEmpty()) {
            return JSON.serialize(new Map<String, String>{'error' => 'Cannot send email. This quote is currently in the approval process.'});
        }

        List<ProcessInstance> recentInstances = [
            SELECT Id, Status
            FROM ProcessInstance
            WHERE TargetObjectId = :quoteId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!recentInstances.isEmpty() && recentInstances[0].Status == 'Rejected') {
            return JSON.serialize(new Map<String, String>{'error' => 'Cannot send email. The most recent approval request was rejected.'});
        }

        Quote quote = [
            SELECT Id, Name, Email, ContactId, Status, Contact.Name,
                Contact.FirstName, Contact.Email, Contact.Phone,
                Owner.Phone, Owner.Name, Owner.Title, Owner.Email,
                (SELECT Id, Quantity, UnitPrice, PricebookEntry.Product2.Name FROM QuoteLineItems)
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        Set<String> allowedStatuses = new Set<String>{'Send to Customer', 'Negotiation', 'Accepted'};
        if (!allowedStatuses.contains(quote.Status)) {
            return JSON.serialize(new Map<String, String>{'error' => 'Cannot send email. The quote is in ' + quote.Status + ' stage so we cannot perform this operation.'});
        }

        String recipientEmail = String.isNotBlank(quote.Email) ? quote.Email :
            (quote.ContactId != null && String.isNotBlank(quote.Contact.Email)) ? quote.Contact.Email : null;

        if (String.isBlank(recipientEmail)) {
            return JSON.serialize(new Map<String, String>{'error' => 'No valid email found in Quote or related Contact.'});
        }

        PageReference pdfPage = new PageReference('/apex/OfferPdf?quoteId=' + quoteId);
        Blob pdfBlob = Test.isRunningTest() ? Blob.valueOf('Test PDF content') : pdfPage.getContentAsPDF();

        String pdfTitle = 'Quote_' + quoteId + '_' + Datetime.now().format('yyyy-MM-dd_HH-mm-ss') + 'Email.pdf';
        ContentVersion contentVersion = new ContentVersion(
            Title = pdfTitle,
            PathOnClient = pdfTitle,
            VersionData = pdfBlob,
            ContentLocation = 'S',
            IsMajorVersion = true
        );
        insert contentVersion;

        contentVersion = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :contentVersion.Id
            LIMIT 1
        ];

        insert new ContentDocumentLink(
            ContentDocumentId = contentVersion.ContentDocumentId,
            LinkedEntityId = quoteId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        EmailTemplate template = [
            SELECT Id, HtmlValue, Name
            FROM EmailTemplate
            WHERE Name = 'Offer Template'
            LIMIT 1
        ];
        String htmlBody = template.HtmlValue;

        String productSummary = '<table border="1" cellpadding="4" cellspacing="0">';
        productSummary += '<tr>'
                        + '<th>Product Name</th>'
                        + '<th>Quantity</th>'
                        + '<th>Unit Price (₹)</th>'
                        + '</tr>';

        for (QuoteLineItem item : quote.QuoteLineItems) {
            productSummary += '<tr>'
                            + '<td>' + item.PricebookEntry.Product2.Name + '</td>'
                            + '<td>' + String.valueOf(item.Quantity) + '</td>'
                            + '<td>' + String.valueOf(item.UnitPrice) + '</td>'
                            + '</tr>';
        }
        productSummary += '</table>';

        if (quote.QuoteLineItems.isEmpty()) {
            productSummary = 'Product details not available.';
        }

        htmlBody = htmlBody
            .replace('[FirstName]', String.isNotBlank(quote.Contact.FirstName) ? quote.Contact.FirstName : 'Valued Customer')
            .replace('[Phone Number]', String.isNotBlank(quote.Owner.Phone) ? quote.Owner.Phone : '')
            .replace('[Email Address]', String.isNotBlank(quote.Owner.Email) ? quote.Owner.Email : '')
            .replace('[salesname]', String.isNotBlank(quote.Owner.Name) ? quote.Owner.Name : '')
            .replace('[Website]', 'https://lloyds.in/')
            .replace('[briefly mention the key products/services offered, quantity, pricing, and any other relevant terms]', productSummary);

        if (quote.Owner.Title != null) {
            htmlBody = htmlBody.replace('[SalesTitle]', quote.Owner.Title);
        } else {
            htmlBody = htmlBody.replace('[SalesTitle]<br>', '');
        }

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { recipientEmail });
        email.setSubject('Offer Submission from Lloyds Metals & Energy Limited');
        email.setHtmlBody(htmlBody);
        email.setWhatId(quoteId);
        email.setTargetObjectId(quote.ContactId);
        email.setTreatTargetObjectAsRecipient(false);
        email.setSaveAsActivity(true);

        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(pdfTitle);
        attachment.setBody(pdfBlob);
        attachment.setContentType('application/pdf');
        email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });

        Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });

        if (!results[0].isSuccess()) {
            return JSON.serialize(new Map<String, String>{'error' => 'Failed to send email: ' + results[0].getErrors()[0].getMessage()});
        }

        return contentVersion.Id;

    } catch (Exception e) {
        System.debug('Error in saveAndEmailPDF: ' + e.getMessage() + ' :: ' + e.getStackTraceString());
        return JSON.serialize(new Map<String, String>{'error' => 'An unexpected error occurred while processing your request: ' + e.getMessage()});
    }
}


// Save PDF method
@AuraEnabled
public static String savePDF(String quoteId) {
    try {
        if (String.isBlank(quoteId)) {
            throw new AuraHandledException('Quote ID is required.');
        }

        Quote quote = [
            SELECT Id, Name,Quote_Number__c
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        PageReference pdfPage = new PageReference('/apex/OfferPdf?quoteId=' + quoteId);
        Blob pdfBlob = Test.isRunningTest() ? Blob.valueOf('Test PDF content') : pdfPage.getContentAsPDF();

        String pdfTitle = 'Quote_' + quote.Quote_Number__c + '_' + Datetime.now().format('yyyy-MM-dd_HH-mm-ss') + 'saved.pdf';

        ContentVersion contentVersion = new ContentVersion(
            Title = pdfTitle,
            PathOnClient = pdfTitle,
            VersionData = pdfBlob,
            ContentLocation = 'S',
            IsMajorVersion = true
        );
        insert contentVersion;

        contentVersion = [
            SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1
        ];

        insert new ContentDocumentLink(
            ContentDocumentId = contentVersion.ContentDocumentId,
            LinkedEntityId = quoteId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        return contentVersion.Id;

    } catch (Exception e) {
        System.debug('Error in savePDF: ' + e.getMessage());
        throw new AuraHandledException('Failed to save PDF: ' + e.getMessage());
    }
}
    

}