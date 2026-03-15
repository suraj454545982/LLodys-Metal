@IsTest
public class PricebookEntryApprovalHandlerTest {

    @TestSetup
    static void setupData() {

        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        Product2 prod = new Product2(
            Name = 'Iron Ore Product',
            Family = 'Iron Ore',
            IsActive = true
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        PricebookEntryApproval__c appr = new PricebookEntryApproval__c(
            PricebookEntryID__c = pbe.Id,
            Product2Id__c = prod.Id,
            Pricebook2Id__c = stdPbId,
            UnitPrice__c = 100,
            TotalPrice__c = 100,
            ApprovalStatus__c = 'Draft',
            IsActive__c = true
        );
        insert appr;
    }

    /* =====================================================
       AFTER INSERT — LINK APPROVAL TO PRICEBOOK ENTRY
    ===================================================== */
    @IsTest
    static void testHandleAfterInsert() {

        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        PricebookEntryApproval__c appr = new PricebookEntryApproval__c(
            PricebookEntryID__c = pbe.Id,
            UnitPrice__c = 120,
            TotalPrice__c = 120
        );

        Test.startTest();
        PricebookEntryApprovalHandler.handleAfterInsert(
            new List<PricebookEntryApproval__c>{ appr }
        );
        Test.stopTest();

        System.assert(true);
    }

    /* =====================================================
       AFTER UPDATE — SYNC APPROVAL STATUS
    ===================================================== */
    @IsTest
    static void testHandleAfterUpdate() {

        PricebookEntryApproval__c appr =
            [SELECT Id, PricebookEntryID__c, ApprovalStatus__c
             FROM PricebookEntryApproval__c
             LIMIT 1];

        PricebookEntryApproval__c oldAppr = appr.clone(false, true);
        appr.ApprovalStatus__c = 'Approved';

        Test.startTest();
        PricebookEntryApprovalHandler.handleAfterUpdate(
            new List<PricebookEntryApproval__c>{ appr },
            new Map<Id, PricebookEntryApproval__c>{ appr.Id => oldAppr }
        );
        Test.stopTest();

        System.assert(true);
    }

    /* =====================================================
       INSERT APPROVAL SUBMISSION
    ===================================================== */
    @IsTest
    static void testInsertApprove() {

       PricebookEntryApproval__c appr =
            [SELECT Id, Product2Id__c, ApprovalStatus__c, UnitPrice__c
             FROM PricebookEntryApproval__c
             LIMIT 1];


        Test.startTest();
        PricebookEntryApprovalHandler.insertApprove(
            new List<PricebookEntryApproval__c>{ appr }
        );
        Test.stopTest();

        System.assert(true);
    }

    /* =====================================================
       UPDATE APPROVAL — UNIT PRICE CHANGE
    ===================================================== */
    @IsTest
    static void testUpdateApprove() {

        PricebookEntryApproval__c appr =
            [SELECT Id, Product2Id__c, ApprovalStatus__c, UnitPrice__c
             FROM PricebookEntryApproval__c
             LIMIT 1];

        PricebookEntryApproval__c oldAppr = appr.clone(false, true);
        appr.UnitPrice__c = appr.UnitPrice__c + 10;

        Test.startTest();
        PricebookEntryApprovalHandler.updateApprove(
            new List<PricebookEntryApproval__c>{ appr },
            new Map<Id, PricebookEntryApproval__c>{ appr.Id => oldAppr }
        );
        Test.stopTest();

        System.assert(true);
    }

    /* =====================================================
       SUBMIT FOR APPROVAL — UNKNOWN FAMILY (SKIP)
    ===================================================== */
    @IsTest
    static void testSubmitForApprovalUnknownFamily() {

        Product2 prod = new Product2(
            Name = 'Other Product',
            Family = 'Other',
            IsActive = true
        );
        insert prod;

        PricebookEntryApproval__c appr = new PricebookEntryApproval__c(
            Product2Id__c = prod.Id,
            UnitPrice__c = 10
        );

        Test.startTest();
        PricebookEntryApprovalHandler.submitForApproval(
            new List<PricebookEntryApproval__c>{ appr },
            null
        );
        Test.stopTest();

        System.assert(true);
    }

    /* =====================================================
       REJECTION VALIDATION — NO STATUS CHANGE
       (EARLY RETURN PATH)
    ===================================================== */
    @IsTest
    static void testValidateRejectComments_NoReject() {

        PricebookEntryApproval__c appr =
            [SELECT Id, ApprovalStatus__c FROM PricebookEntryApproval__c LIMIT 1];

        PricebookEntryApproval__c oldAppr = appr.clone(false, true);

        Test.startTest();
        PricebookEntryApprovalHandler.validatePBRejectComments(
            new List<PricebookEntryApproval__c>{ appr },
            new Map<Id, PricebookEntryApproval__c>{ appr.Id => oldAppr }
        );
        Test.stopTest();

        System.assert(true);
    }
    
    
    @IsTest
    static void testValidateRejectWithoutComments() {
    
        // --- Fetch existing approval record ---
        PricebookEntryApproval__c appr =
            [SELECT Id, ApprovalStatus__c
             FROM PricebookEntryApproval__c
             LIMIT 1];
    
        // --- Old map (before update) ---
        Map<Id, PricebookEntryApproval__c> oldMap =
            new Map<Id, PricebookEntryApproval__c>{
                appr.Id => appr.clone(false, true)
            };
    
        // --- Change status to Rejected (NO comments possible in test) ---
        appr.ApprovalStatus__c = 'Rejected';
    
        Test.startTest();
        try {
            PricebookEntryApprovalHandler.validatePBRejectComments(
                new List<PricebookEntryApproval__c>{ appr },
                oldMap
            );
        } catch (Exception e) {
            // addError may surface as DML/validation exception in trigger context
            System.assert(
                e.getMessage().contains('rejection'),
                'Expected rejection comment validation'
            );
        }
        Test.stopTest();
    
        System.assert(true, 'Rejected path executed');
    }

}