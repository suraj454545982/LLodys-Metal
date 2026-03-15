@IsTest
public class SalesContractTestDataFactory {

    // Wrapper to return all important Ids
    public class TestData {
        public Id accountId;
        public Id opportunityId;
        public Id productId;
        public Id quoteId;
        public Id purchaseOrderId;
        public Id pricebookEntryId;
    }

    /**
     * Creates fully approved PO data
     * Matches setupOnce() exactly
     */
    public static TestData createApprovedPOData() {

        TestData data = new TestData();

        /* -------------------------------
         * Standard Pricebook
         * ------------------------------- */
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        /* -------------------------------
         * Account
         * ------------------------------- */
        Account acc = new Account(
            Name = 'Test Account New',
            Phone = '9999999989',
            Organization_Code__c = '2000',
            Distribution_Channel__c = '20',
            Division__c = '0',
            SAP_Customer_Code__c = 'SAP1023'
        );
        insert acc;
        data.accountId = acc.Id;

        /* -------------------------------
         * Product
         * ------------------------------- */
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            Plant__c = '2060',
            Family = 'Iron Ore'
        );
        insert prod;
        data.productId = prod.Id;

        /* -------------------------------
         * Pricebook Entry
         * ------------------------------- */
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            ApprovalStatus_c__c = 'Approved',
            Validity_Date__c = Date.today()
        );
        insert pbe;
        data.pricebookEntryId = pbe.Id;

        /* -------------------------------
         * Opportunity
         * ------------------------------- */
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            Category__c = 'Iron Ore',
            Plant_and_Shipping_Point__c = '2060',
            PO_Received__c = 'Yes'
        );
        insert opp;

        /* -------------------------------
         * Opportunity Line Item
         * MUST exist before Quotation
         * ------------------------------- */
        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 100,
            UnitPrice = 100
        );

        opp.StageName = 'Quotation';
        update opp;

        data.opportunityId = opp.Id;

        /* -------------------------------
         * Quote
         * ------------------------------- */
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            BillingName = 'Billing Name',
            Additional_Terms_and_Condition__c = 'this is sample text'
        );
        insert q;



        /* -------------------------------
         * Quote Line Item
         * ------------------------------- */
        insert new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Product2Id = prod.Id,
            Quantity = 100,
            UnitPrice = 100
        );
        
        q.Status = 'Accepted';
        update q;

        data.quoteId = q.Id;

        /* -------------------------------
         * Purchase Order
         * ------------------------------- */
        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'PO-001',
            Opportunity__c = opp.Id,
            Quote__c = q.Id,
            PO_Approval_Status__c = 'Draft',
            PO_Date__c = Date.today()
        );
        insert po;

        
        /* -------------------------------
         * Upload File (Approval requirement)
         * ------------------------------- */
        ContentVersion cv = new ContentVersion(
            Title = 'PO File',
            PathOnClient = 'po.pdf',
            VersionData = Blob.valueOf('test'),
            IsMajorVersion = true
        );
        insert cv;

        Id contentDocId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ].ContentDocumentId;

        insert new ContentDocumentLink(
            LinkedEntityId = po.Id,
            ContentDocumentId = contentDocId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        /* -------------------------------
         * Approve PO
         * ------------------------------- */
        
        po.PO_Approval_Status__c = 'Approved';
        update po;

        data.purchaseOrderId = po.Id;

        return data;
    }
    


}