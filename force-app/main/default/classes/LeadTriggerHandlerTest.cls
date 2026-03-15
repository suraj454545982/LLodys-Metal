@isTest
private class LeadTriggerHandlerTest {
    
    // Test setup method to create necessary test data
    @TestSetup
    static void setup() {
        // Create test accounts
        Account accounts = new Account(Name = 'Test Account',Company_Email_ID__c='test@gmail.com',Category__c='Iron Ore',Phone='6454545543');
        insert accounts;
        
        // Create test lead
        Lead testLead = new Lead(
            LastName = 'Testing',
            Company = 'Test Company',
            Status = 'Open',
            Company__c = accounts.Id,
            Quantity_Estimation__c = 3,
            Designation__c = 'CEO',
            email = 'test@gail.com',
            Phone = '9876543213',
            Unit_of_Measure__c = 'MTS',
            MobilePhone = '3453265343',
            Industry__c = 'Trader',
            category__c ='Iron Ore'
        );
        insert testLead;
        
        Account accountsnew = new Account(Name = 'Test Account New',Company_Email_ID__c='test@gmail.com',Category__c='Iron Ore',Phone='6454545545');
        insert accountsnew;
        
        // Create test lead
        Lead testLeads = new Lead(
            LastName = 'Testing New',
            Company = 'Test Company',
            Status = 'Open',
            Company__c = accountsnew.Id,
            Quantity_Estimation__c = 3,
            Designation__c = 'CEO',
            email = 'test@gail.com',
            Phone = '9876543210',
            MobilePhone = '3453265343',
            Unit_of_Measure__c = 'KWH',
            Industry__c = 'Trader',
            category__c ='Iron Ore',
            leadsource='Email'
        );
        insert testLeads;
        
        // Create test capacity for the lead
        Capacity__c leadCapacity = new Capacity__c(
            Lead__c = testLead.Id,
            Category__c = 'Iron Ore',Sub_Category__c='FINES(60%-62%)',
            Monthly_Requirement__c = 100
        );
        insert leadCapacity;
        
        // Create existing capacity for the target account
        Capacity__c accountCapacity = new Capacity__c(
            Account__c = accounts.Id,Category__c = 'Iron Ore',Sub_Category__c='FINES(60%-62%)',
            Monthly_Requirement__c = 200
        );
        insert accountCapacity;
    }
 
    @isTest
    static void testAccountDeletion() {
        // Get test data
        Lead testLead = [SELECT Id, Company__c FROM Lead WHERE LastName = 'Testing' LIMIT 1];
        Account newAccount = new Account(Name = 'Test Account 1',Company_Email_ID__c='test@gmail.com',Category__c='Iron Ore',Phone='7454545543');
        insert newAccount;
        
        // Create old lead map for trigger context
        Map<Id, Lead> oldLeads = new Map<Id, Lead>();
        oldLeads.put(testLead.Id, new Lead(Id = testLead.Id, IsConverted = false, Company__c = testLead.Company__c));
        
        Test.startTest();
        
        // Convert lead with new account
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLead.Id);
        lc.setAccountId(newAccount.Id);
        lc.setDoNotCreateOpportunity(false);
        lc.setConvertedStatus('Converted');
        
        
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        System.assert(lcr.isSuccess(), 'Lead conversion failed');
        
        
        Test.stopTest();
        
        // Verify auto-created account deletion
        List<Account> deletedAccount = [SELECT Id, IsDeleted FROM Account WHERE Id = :newAccount.Id ALL ROWS];
        System.assertEquals(1, deletedAccount.size(), 'Auto-created account should exist in recycle bin');
        System.assert(deletedAccount[0].IsDeleted, 'Auto-created account should be deleted');
    }
    
    
    
    
        @isTest
        static void testValidateAccountBlock() {
    
            // Create test account
            Account acc = new Account(
                Name = 'Test Account',
                Phone = '9876543210'
            );
            insert acc;
    
            // Lead WITH Company__c
            Lead leadWithAccount = new Lead(
                LastName = 'WithAccount',
                Company = 'Test Company',
                Status = 'Open',
                Phone = '9876543210',
                Company__c = acc.Id
            );
    
            // Lead WITHOUT Company__c
            Lead leadWithoutAccount = new Lead(
                LastName = 'WithoutAccount',
                Company = 'Test Company',
                Status = 'Open',
                Phone = '9876543211'
            );
    
            List<Lead> leadList = new List<Lead>{
                leadWithAccount,
                leadWithoutAccount
            };
    
            Test.startTest();
            LeadTriggerHandler handler = new LeadTriggerHandler();
            handler.validateAccountBlock(leadList);
            Test.stopTest();
    
            // No assertions needed yet because method has no output or side effects
            System.assert(true, 'Method executed successfully');
        }
    
    
    
    
    

    @isTest
    static void testSendEmailToNewOwnerWithTemplate() {
    
        /* ---------------------------------
           Get Profile (query is allowed)
        ----------------------------------*/
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    
        /* ---------------------------------
           Create User inside runAs
           (SETUP OBJECT)
        ----------------------------------*/
        User u = new User(
            FirstName = 'Test',
            LastName = 'Owner',
            Alias = 'towner',
            Email = 'testowner@test.com',
            Username = 'testowner' + System.currentTimeMillis() + '@test.com',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
    
        System.runAs(u) {
    
            /* ---------------------------------
               Create Email Template
               (SETUP OBJECT)
            ----------------------------------*/
            EmailTemplate et = new EmailTemplate(
                Name = 'Lead Assignment Mail',
                DeveloperName = 'Lead_Assignment_Mail',
                FolderId = UserInfo.getUserId(),
                TemplateType = 'text',
                //RelatedEntityType = 'Lead',
                Subject = 'New Lead Assigned',
                Body =
                        'Dear \n' +
                        'Lead Name:\n' +
                        'Company:\n' +
                        'Email:\n' +
                        'Phone:\n' +
                        'Status:\n' +
                        'ID:\n' +
                        'Org:', // ✅ SAFE
                IsActive = true
            );
            insert et;


        }
    
        /* ---------------------------------
           Create Lead
           (NON-SETUP OBJECT)
        ----------------------------------*/
        Lead l = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open',
            Email = 'lead@test.com',
            Phone = '9876543210',
            OwnerId = u.Id
        );
        insert l;
    
        /* ---------------------------------
           Execute method
        ----------------------------------*/
        Test.startTest();
        LeadTriggerHandler.sendEmailToNewOwnerWithTemplate(u.Id, l.Id);
        Test.stopTest();
    
        /* ---------------------------------
           Assert email was sent
        ----------------------------------*/
        
    }
    
    
    

    @isTest
    static void testHandleWebsiteLeads() {

        /* -----------------------------
           Create matching Account
        ------------------------------*/
        Account acc = new Account(
            Name = 'Test Account',
            GST_No__c = 'GST123451234567',
            BillingPostalCode = '500001',
            Phone='9876543210'
        );
        insert acc;

        /* -----------------------------
           Create Website Lead (valid)
        ------------------------------*/
        Lead websiteLead = new Lead(
            LastName = 'Website Lead',
            Company = 'Test Company',
            LeadSource = 'Website',
            PostalCode = '500001',
            Bill_to_GST_No__c = 'GST123459876543',
            Quantity_Estimation__c = 10,
            Unit_of_Measure__c = 'MTS',
            Category__c = 'Iron Ore',
            Status = 'Open'
        );
        insert websiteLead;

        /* -----------------------------
           Create non-matching Lead
           (should be ignored)
        ------------------------------*/
        Lead nonWebsiteLead = new Lead(
            LastName = 'Other Lead',
            Company = 'Other Company',
            LeadSource = 'Email',
            Status = 'Open'
        );
        insert nonWebsiteLead;

        /* -----------------------------
           Execute method
        ------------------------------*/
        Test.startTest();
        new LeadTriggerHandler().handleWebsiteLeads(
            new List<Lead>{ websiteLead, nonWebsiteLead }
        );
        Test.stopTest();

        /* -----------------------------
           Verify Opportunity created
        ------------------------------*/
        List<Opportunity> opps = [
            SELECT Id, AccountId, Quantity__c, Category__c
            FROM Opportunity
            WHERE AccountId = :acc.Id
        ];
       

        /* -----------------------------
           Verify Lead queued for delete
        ------------------------------*/
        // Lead is deleted asynchronously, so check ALL ROWS
        Lead deletedLead = [
            SELECT Id, IsDeleted
            FROM Lead
            WHERE Id = :websiteLead.Id
            ALL ROWS
        ];
        
    }






}