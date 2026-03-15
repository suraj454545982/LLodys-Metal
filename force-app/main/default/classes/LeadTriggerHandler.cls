public class LeadTriggerHandler {
    
    public void handleAfterUpdate(List<Lead> newLeads, Map<Id, Lead> oldLeads) {
        Map<Id, Opportunity> oppMapToUpdate = new Map<Id, Opportunity>();
        List<Contact> contactsToUpdate = new List<Contact>();
        List<Account> accountsToDelete = new List<Account>();
        
        List<Id> convertedLeadIds = new List<Id>();
        Map<Id, Id> leadToAccountMap = new Map<Id, Id>();
        
        for (Lead l : newLeads) {
            Lead oldLead = oldLeads.get(l.Id);
            
            // Lead was just converted
            if (!oldLead.IsConverted && l.IsConverted && (l.Company__c != null || l.ConvertedAccountId != null)) {
                
                // Update the converted Opportunity's Account
                if (l.ConvertedOpportunityId != null) {
                    Opportunity opp = oppMapToUpdate.get(l.ConvertedOpportunityId);
                    if (opp == null) {
                        opp = new Opportunity(Id = l.ConvertedOpportunityId);
                    }
                    opp.AccountId = l.Company__c != null ? l.Company__c : l.ConvertedAccountId;
                    oppMapToUpdate.put(opp.Id, opp);
                }
                
                // Update the converted Contact's Account
                if (l.ConvertedContactId != null) {
                    contactsToUpdate.add(new Contact(
                        Id = l.ConvertedContactId,
                        AccountId = l.Company__c != null ? l.Company__c : l.ConvertedAccountId
                    ));
                }
                
                // Store Lead-to-Account mapping for Capacity reassignment
                if (l.ConvertedAccountId != null) {
                    convertedLeadIds.add(l.Id);
                    
                    Id targetAccountId = l.Company__c != null ? l.Company__c : l.ConvertedAccountId;
                    leadToAccountMap.put(l.Id, targetAccountId);
                    
                    // Delete auto-created Account only if Company__c is used
                    if (l.Company__c != null) {
                        accountsToDelete.add(new Account(Id = l.ConvertedAccountId));
                    }
                }
            }
            
            // Always sync LeadSource to Opportunity if available
            if (l.IsConverted && l.ConvertedOpportunityId != null) {
                Opportunity opp = oppMapToUpdate.get(l.ConvertedOpportunityId);
                if (opp == null) {
                    opp = new Opportunity(Id = l.ConvertedOpportunityId);
                }
                opp.LeadSource = l.LeadSource;
                oppMapToUpdate.put(opp.Id, opp);
            }
        }
        
        // Apply updates
        if (!contactsToUpdate.isEmpty()) update contactsToUpdate;
        if (!oppMapToUpdate.isEmpty()) update oppMapToUpdate.values();
        if (!accountsToDelete.isEmpty()) delete accountsToDelete;
        
        // Capacity reassignment logic
        if (!convertedLeadIds.isEmpty()) {
            List<Capacity__c> leadCapacities = [
                SELECT Id, Lead__c, Account__c, Category__c, Sub_Category__c, Monthly_Requirement__c
                FROM Capacity__c
                WHERE Lead__c IN :convertedLeadIds
            ];
            
            Set<Id> accountIds = new Set<Id>(leadToAccountMap.values());
            
            List<Capacity__c> existingAccountCaps = [
                SELECT Id, Account__c, Category__c, Sub_Category__c, Monthly_Requirement__c
                FROM Capacity__c
                WHERE Account__c IN :accountIds
            ];
            
            Map<Id, List<Capacity__c>> accountCapMap = new Map<Id, List<Capacity__c>>();
            for (Capacity__c cap : existingAccountCaps) {
                if (!accountCapMap.containsKey(cap.Account__c)) {
                    accountCapMap.put(cap.Account__c, new List<Capacity__c>());
                }
                accountCapMap.get(cap.Account__c).add(cap);
            }
            
            List<Capacity__c> toUpdate = new List<Capacity__c>();
            
            for (Capacity__c cap : leadCapacities) {
                Id accId = leadToAccountMap.get(cap.Lead__c);
                Boolean alreadyExists = false;
                
                if (accountCapMap.containsKey(accId)) {
                    for (Capacity__c existing : accountCapMap.get(accId)) {
                        if (existing.Category__c == cap.Category__c &&
                            existing.Sub_Category__c == cap.Sub_Category__c &&
                            existing.Monthly_Requirement__c == cap.Monthly_Requirement__c) {
                                alreadyExists = true;
                                break;
                            }
                    }
                }
                
                if (!alreadyExists) {
                    cap.Account__c = accId;
                    toUpdate.add(cap);
                }
            }
            
            if (!toUpdate.isEmpty()) {
                update toUpdate;
            }
        }
    }
    
    public void handleWebsiteLeads(List<Lead> newLeads) {
        
        if (newLeads == null || newLeads.isEmpty()) return;
        
        // 1. Filter Website Leads with required fields
        List<Lead> websiteLeads = new List<Lead>();
        for (Lead l : newLeads) {
            if (
                l.LeadSource == 'Website' &&
                String.isNotBlank(l.PostalCode) &&
                String.isNotBlank(l.Bill_to_GST_No__c)
            ) {
                websiteLeads.add(l);
            }
        }
        
        if (websiteLeads.isEmpty()) return;
        
        // 2. Collect GST & Postal Code
        Set<String> gstSet = new Set<String>();
        Set<String> postalSet = new Set<String>();
        
        for (Lead l : websiteLeads) {
            gstSet.add(l.Bill_to_GST_No__c.trim().toUpperCase());
            postalSet.add(l.PostalCode.trim());
        }
        
        // 3. Query Accounts
        Map<String, Account> accountMap = new Map<String, Account>();
        
        for (Account acc : [
            SELECT Id, GST_No__c, BillingPostalCode
            FROM Account
            WHERE GST_No__c IN :gstSet
            AND BillingPostalCode IN :postalSet
        ]) {
            String key = acc.GST_No__c.trim().toUpperCase()
                + '-' +
                acc.BillingPostalCode.trim();
            accountMap.put(key, acc);
        }
        
        if (accountMap.isEmpty()) return;
        
        // 4. Prepare Opportunities & Lead Ids to delete
        List<Opportunity> oppsToInsert = new List<Opportunity>();
        List<Id> leadIdsToDelete = new List<Id>();
        Set<Id> processedAccountIds = new Set<Id>();
        
        for (Lead l : websiteLeads) {
            
            String key = l.Bill_to_GST_No__c.trim().toUpperCase()
                + '-' +
                l.PostalCode.trim();
            
            if (accountMap.containsKey(key)) {
                
                Account acc = accountMap.get(key);
                
                // Prevent duplicate Opportunity per Account
                if (!processedAccountIds.contains(acc.Id)) {
                    
                    oppsToInsert.add(new Opportunity(
                        Name       = 'Website Opportunity - ' + l.Company,
                        AccountId  = acc.Id,
                        StageName  = 'Qualification',
                        CloseDate = Date.today().addDays(30),
                        Quantity__c = l.Quantity_Estimation__c,
                        Unit_Of_Measure__c = l.Unit_of_Measure__c,
                        LeadSource = l.Category__c,
                        Category__c = l.Category__c
                    ));
                    
                    processedAccountIds.add(acc.Id);
                }
                
                leadIdsToDelete.add(l.Id);
            }
        }
        
        // 5. DML
        if (!oppsToInsert.isEmpty()) {insert oppsToInsert;}
        
        // 6. Async Lead Deletion (Separate Transaction)
        if (!leadIdsToDelete.isEmpty()) {
            System.enqueueJob( new DeleteWebsiteLeads(leadIdsToDelete) );
        }
    }
    
    public void assignLeads(List<Lead> leads, Map<Id, Lead> oldLeads, Boolean isInsert) {
        Map<String, List<Lead>> leadsByCategory = new Map<String, List<Lead>>();
        Set<Id> leadIds = new Set<Id>();
        
        // Step 1: Group leads by category
        for (Lead l : leads) {
            if(l.LeadSource != 'Other'){
                Boolean shouldProcess = isInsert || 
                    (oldLeads != null && (
                        l.Category__c != oldLeads.get(l.Id).Category__c || 
                        l.LeadSource == 'Website' || 
                        l.LeadSource == 'Email' || 
                        l.LeadSource == 'Social Media' 
                        
                    ) );
                
                if (shouldProcess && l.Category__c != null) {
                    if (!leadsByCategory.containsKey(l.Category__c)) {
                        leadsByCategory.put(l.Category__c, new List<Lead>());
                    }
                    leadsByCategory.get(l.Category__c).add(l);
                    if (!isInsert) leadIds.add(l.Id);  // Only collect IDs if not insert
                }
            }
            
            if (leadsByCategory.isEmpty()) return;
            
            // Step 2: Load CMDT category-to-queue mapping
            Map<String, String> categoryToQueue = new Map<String, String>();
            for (Lead_Queue_Mapping__mdt mapping : [
                SELECT Category__c, Queue_Name__c 
                FROM Lead_Queue_Mapping__mdt 
                WHERE Category__c IN :leadsByCategory.keySet()
            ]) {
                categoryToQueue.put(mapping.Category__c, mapping.Queue_Name__c);
            }
            
            // Step 3: Get all queue group Ids
            Map<String, Id> queueNameToId = new Map<String, Id>();
            for (Group queue : [
                SELECT Id, DeveloperName 
                FROM Group 
                WHERE Type = 'Queue' 
                AND DeveloperName IN :categoryToQueue.values()
            ]) {
                queueNameToId.put(queue.DeveloperName, queue.Id);
            }
            
            // Step 4: Get all queue members
            Map<Id, List<Id>> queueToUserIds = new Map<Id, List<Id>>();
            for (GroupMember gm : [
                SELECT GroupId, UserOrGroupId 
                FROM GroupMember 
                WHERE GroupId IN :queueNameToId.values()
            ]) {
                if (!queueToUserIds.containsKey(gm.GroupId)) {
                    queueToUserIds.put(gm.GroupId, new List<Id>());
                }
                queueToUserIds.get(gm.GroupId).add(gm.UserOrGroupId);
            }
            
            // Step 5: Get last assigned leads for each category
            Map<String, Id> categoryToLastOwner = new Map<String, Id>();
            if (!isInsert && !leadIds.isEmpty()) {
                for (Lead lastLead : [
                    SELECT Category__c, OwnerId
                    FROM Lead
                    WHERE Category__c IN :leadsByCategory.keySet()
                    AND Id NOT IN :leadIds
                    AND OwnerId IN :getAllUserIds(queueToUserIds)
                    ORDER BY CreatedDate DESC
                ]) {
                    if (!categoryToLastOwner.containsKey(lastLead.Category__c)) {
                        categoryToLastOwner.put(lastLead.Category__c, lastLead.OwnerId);
                    }
                }
            }
            
            // Step 6: Round-robin assignment
            for (String category : leadsByCategory.keySet()) {
                if (!categoryToQueue.containsKey(category)) continue;
                
                String queueName = categoryToQueue.get(category);
                Id queueId = queueNameToId.get(queueName);
                if (queueId == null) continue;
                
                List<Id> userIds = queueToUserIds.get(queueId);
                if (userIds == null || userIds.isEmpty()) continue;
                
                Integer startIndex = 0;
                Id lastOwnerId = categoryToLastOwner.get(category);
                if (lastOwnerId != null) {
                    Integer lastIndex = userIds.indexOf(lastOwnerId);
                    if (lastIndex != -1) {
                        startIndex = Math.mod(lastIndex + 1, userIds.size());
                    }
                }
                
                List<Lead> categoryLeads = leadsByCategory.get(category);
                for (Integer i = 0; i < categoryLeads.size(); i++) {
                    Integer index = Math.mod(startIndex + i, userIds.size());
                    categoryLeads[i].OwnerId = userIds[index];  // Direct assignment
                }
            } 
        }
        
    }   
    
    public void assignLeadOwnersAfterInsert(List<Lead> leads) {
        Map<String, List<Lead>> leadsByCategory = new Map<String, List<Lead>>();
        Set<Id> leadIds = new Set<Id>();
        
        // Step 1: Group leads by category
        for (Lead l : leads) {
            if (l.Category__c != null && (l.LeadSource == 'Website' || l.LeadSource == 'Email' || l.LeadSource == 'Social Media')) {
                if (!leadsByCategory.containsKey(l.Category__c)) {
                    leadsByCategory.put(l.Category__c, new List<Lead>());
                }
                leadsByCategory.get(l.Category__c).add(l);
                leadIds.add(l.Id);
            }
        }
        
        if (leadsByCategory.isEmpty()) {
            return;
        }
        
        // Step 2: Load CMDT category-to-queue mapping
        Map<String, String> categoryToQueue = new Map<String, String>();
        for (Lead_Queue_Mapping__mdt mapping : [
            SELECT Category__c, Queue_Name__c 
            FROM Lead_Queue_Mapping__mdt 
            WHERE Category__c IN :leadsByCategory.keySet()
        ]) {
            categoryToQueue.put(mapping.Category__c, mapping.Queue_Name__c);
        }
        
        // Step 3: Get all queues in one query
        Map<String, Id> queueNameToId = new Map<String, Id>();
        for (Group queue : [
            SELECT Id, DeveloperName
            FROM Group 
            WHERE Type = 'Queue' 
            AND DeveloperName IN :categoryToQueue.values()
        ]) {
            queueNameToId.put(queue.DeveloperName, queue.Id);
        }
        
        // Step 4: Get all group members in one query
        Map<Id, List<Id>> queueToUserIds = new Map<Id, List<Id>>();
        for (GroupMember gm : [
            SELECT GroupId, UserOrGroupId 
            FROM GroupMember 
            WHERE GroupId IN :queueNameToId.values()
        ]) {
            if (!queueToUserIds.containsKey(gm.GroupId)) {
                queueToUserIds.put(gm.GroupId, new List<Id>());
            }
            queueToUserIds.get(gm.GroupId).add(gm.UserOrGroupId);
        }
        
        // Step 5: Get last assigned leads for all categories, excluding current leads
        Map<String, Id> categoryToLastOwner = new Map<String, Id>();
        for (Lead lastLead : [
            SELECT Category__c, OwnerId
            FROM Lead
            WHERE Category__c IN :leadsByCategory.keySet()
            AND Id NOT IN :leadIds
            AND OwnerId IN :getAllUserIds(queueToUserIds)
            ORDER BY CreatedDate DESC
        ]) {
            if (!categoryToLastOwner.containsKey(lastLead.Category__c)) {
                categoryToLastOwner.put(lastLead.Category__c, lastLead.OwnerId);
            }
        }
        
        // Step 6: Round-robin assignment and collect leads to update
        List<Lead> leadsToUpdate = new List<Lead>();
        for (String category : leadsByCategory.keySet()) {
            if (!categoryToQueue.containsKey(category)) { continue; }
            
            String queueName = categoryToQueue.get(category);
            Id queueId = queueNameToId.get(queueName);
            if (queueId == null) { continue;
                                 }
            
            List<Id> userIds = queueToUserIds.get(queueId);
            if (userIds == null || userIds.isEmpty()) { continue;
                                                      }
            
            Integer startIndex = 0;
            Id lastOwnerId = categoryToLastOwner.get(category);
            if (lastOwnerId != null) {
                Integer lastIndex = userIds.indexOf(lastOwnerId);
                if (lastIndex != -1) {
                    startIndex = Math.mod(lastIndex + 1, userIds.size());
                } 
            } else {
            }
            
            List<Lead> categoryLeads = leadsByCategory.get(category);
            for (Integer i = 0; i < categoryLeads.size(); i++) {
                Integer index = Math.mod(startIndex + i, userIds.size());
                Lead leadToUpdate = new Lead(Id = categoryLeads[i].Id, OwnerId = userIds[index]);
                leadsToUpdate.add(leadToUpdate);
            }
        }
        
        // Step 7: Perform DML update if there are leads to update
        if (!leadsToUpdate.isEmpty()) {
            try {
                update leadsToUpdate;
            } catch (DmlException e) {
                System.debug('Error updating leads: ' + e.getMessage());
            }
        }
    }
    
    @future
    public static void sendEmailToNewOwnerWithTemplate(Id newOwnerId, Id leadId) {
        if (newOwnerId == null || leadId == null || !String.valueOf(newOwnerId).startsWith('005')) return;
        
        // Fetch user and lead
        User user = [SELECT Id, Name, Email FROM User WHERE Id = :newOwnerId AND IsActive = true LIMIT 1];
        Lead lead = [SELECT Id, Name, Company, Email, Phone, Status, Owner.Name FROM Lead WHERE Id = :leadId LIMIT 1];
        
        // Fetch email template body
        EmailTemplate template = [
            SELECT HtmlValue 
            FROM EmailTemplate 
            WHERE DeveloperName = 'Lead_Assignment_Mail' 
            AND IsActive = true 
            LIMIT 1
        ];
        
        if (String.isBlank(user.Email) || String.isBlank(template.HtmlValue) ) return;
        
        // Manually replace merge fields in HTML
        String htmlBody = template.HtmlValue;
        
        htmlBody = htmlBody.replace('{!Lead.OwnerFullName}', lead.Owner.Name != null ? lead.Owner.Name : '');
        htmlBody = htmlBody.replace('{!Lead.Name}', lead.Name != null ? lead.Name : '');
        htmlBody = htmlBody.replace('{!Lead.Company}', lead.Company != null ? lead.Company : '');
        htmlBody = htmlBody.replace('{!Lead.Email}', lead.Email != null ? lead.Email : '');
        htmlBody = htmlBody.replace('{!Lead.Phone}', lead.Phone != null ? lead.Phone : '');
        htmlBody = htmlBody.replace('{!Lead.Status}', lead.Status != null ? lead.Status : '');
        htmlBody = htmlBody.replace('{!Lead.Id}', lead.Id);
        String orgDomainUrl = URL.getOrgDomainUrl().toExternalForm();
        htmlBody = htmlBody.replace('{!$Organization.MyDomain}',orgDomainUrl);
        
        // Prepare and send email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ user.Email });
        email.setSubject('New Lead Assigned'); // Add your subject here
        email.setHtmlBody(htmlBody);
        email.setSaveAsActivity(false);
        
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    } 
    private Set<Id> getAllUserIds(Map<Id, List<Id>> queueToUserIds) {
        Set<Id> userIds = new Set<Id>();
        for (List<Id> users : queueToUserIds.values()) {
            userIds.addAll(users);
        }
        return userIds;
    }
    
    public void validateAccountBlock(List<Lead> leadData){
        Set<Id> accIds = new Set<Id>();
        for(Lead le : leadData){
            if(le.Company__c!=null){
                accIds.add(le.Company__c);  
            }
        }
        if(accIds.size()>0){
            
        }
    }
}