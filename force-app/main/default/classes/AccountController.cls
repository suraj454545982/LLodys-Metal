public without sharing class AccountController {

    @AuraEnabled
    public static List<Account> getAccounts() {
        System.debug('getAccounts called');
        return [SELECT Id, Name,Category__c, Company_Email_ID__c,Additional_Mails__c, Phone FROM Account where Company_Email_ID__c!=null];
    }

    @AuraEnabled
    public static List<Survey__c> createSurveyRecords(List<String> selectedAccountIds,Boolean mail) {
        System.debug('createSurveyRecords called with ' + selectedAccountIds.size() + ' IDs');
        try {
            List<Account> accounts = [
                SELECT Id, Name, Company_Email_ID__c, Phone, Category__c
                FROM Account
                WHERE Id IN :selectedAccountIds
            ];

            List<Survey__c> surveys = new List<Survey__c>();
            for (Account acc : accounts) {
                surveys.add(new Survey__c(
                    name= acc.Name,
                    Account__c = acc.Id,
                    Account_Name__c = acc.Name,
                    Email_Id__c = acc.Company_Email_ID__c,
                    Phone__c = acc.Phone, 
                    Primary_Product__c = acc.Category__c,
                    ismail__c = mail
                ));
            }

            insert surveys;
            System.debug('Inserted survey records: ' + surveys.size());
            return surveys;
        } catch (Exception e) {
            System.debug('Error inserting survey records: ' + e.getMessage());
            return null;
        }
    }
     @AuraEnabled
    public static void updateAccounts(List<Account> accountsToUpdate) {
        try {
            if (!accountsToUpdate.isEmpty()) {
                update accountsToUpdate;
            }
        } catch (Exception e) {
            throw new AuraHandledException('Failed to update accounts: ' + e.getMessage());
        }
    }
}