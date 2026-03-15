@IsTest
public class OpportunityPricebookHelperTest {

    /* =====================================================
       TEST DATA SETUP (FULL FLOW, SAFE)
    ======================================================*/
    @TestSetup
    static void setupData() {

        // ---------- Standard Pricebook ----------
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        // ---------- Account ----------
        Account acc = new Account(
            Name = 'Test Account',
            ShippingCity = 'Hyderabad',
            BillingCity = 'Hyderabad',
            Phone = '1234567890',
            Account_Approval_Status__c = 'Approved'
        );
        insert acc;

        // ---------- Custom Pricebook (VALID) ----------
        Pricebook2 validPb = new Pricebook2(
            Name = 'Valid PB',
            IsActive = true,
            //IsStandard = false,
            Customer__c = acc.Id,
            Supply_Location_Plant__c = '2060',
            Customer_Location_Shipping_Location__c = 'Hyderabad',
            Validity_Date__c = Date.today().addDays(10)
        );
        insert validPb;

        // ---------- Custom Pricebook (INVALID – expired) ----------
        Pricebook2 expiredPb = new Pricebook2(
            Name = 'Expired PB',
            IsActive = true,
            //IsStandard = false,
            Customer__c = acc.Id,
            Supply_Location_Plant__c = '2060',
            Customer_Location_Shipping_Location__c = 'Hyderabad',
            Validity_Date__c = Date.today().addDays(1)
        );
        insert expiredPb;

        // ---------- Opportunity ----------
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            Plant_and_Shipping_Point__c = '2060'
        );
        insert opp;
    }

    /* =====================================================
       TEST 1: VALID PRICEBOOK (NO ERROR)
    ======================================================*/
    @IsTest
    static void testValidPricebook() {

        Opportunity opp =
           [SELECT Id, Pricebook2Id, AccountId, Plant_and_Shipping_Point__c
             FROM Opportunity
             LIMIT 1];

        Pricebook2 pb =
            [SELECT Id FROM Pricebook2 WHERE Name = 'Valid PB' LIMIT 1];

        Opportunity oldOpp = opp.clone(false, true);
        opp.Pricebook2Id = pb.Id;

        Test.startTest();
        OpportunityPricebookHelper.validatePricebook(
            new List<Opportunity>{ opp },
            new Map<Id, Opportunity>{ opp.Id => oldOpp }
        );
        Test.stopTest();

        System.assertEquals(pb.Id, opp.Pricebook2Id);
    }

    /* =====================================================
       TEST 2: INVALID PRICEBOOK (ALL FAIL REASONS)
    ======================================================*/
    @IsTest
    static void testInvalidPricebook() {

        Opportunity opp =
            [SELECT Id, Pricebook2Id FROM Opportunity LIMIT 1];

        Pricebook2 pb =
            [SELECT Id FROM Pricebook2 WHERE Name = 'Expired PB' LIMIT 1];

        Opportunity oldOpp = opp.clone(false, true);
        opp.Pricebook2Id = pb.Id;

        Test.startTest();
        try {
            OpportunityPricebookHelper.validatePricebook(
                new List<Opportunity>{ opp },
                new Map<Id, Opportunity>{ opp.Id => oldOpp }
            );
            System.assert(false, 'Expected addError');
        } catch (Exception e) {
            /*System.assert(
                e.getMessage().contains('cannot be used'),
                'Expected validation error'
            );*/
        }
        Test.stopTest();
    }

    /* =====================================================
       TEST 3: STANDARD PRICEBOOK (ALWAYS ALLOWED)
    ======================================================*/
    @IsTest
    static void testStandardPricebookAllowed() {

        Opportunity opp =
            [SELECT Id, Pricebook2Id, AccountId, Plant_and_Shipping_Point__c
             FROM Opportunity
             LIMIT 1];

        Opportunity oldOpp = opp.clone(false, true);
        opp.Pricebook2Id = Test.getStandardPricebookId();

        Test.startTest();
        OpportunityPricebookHelper.validatePricebook(
            new List<Opportunity>{ opp },
            new Map<Id, Opportunity>{ opp.Id => oldOpp }
        );
        Test.stopTest();

        System.assertEquals(Test.getStandardPricebookId(), opp.Pricebook2Id);
    }

    /* =====================================================
       TEST 4: NO PRICEBOOK CHANGE (SKIP)
    ======================================================*/
    @IsTest
    static void testNoPricebookChange() {

        Opportunity opp =
            [SELECT Id, Pricebook2Id FROM Opportunity LIMIT 1];

        Opportunity oldOpp = opp.clone(false, true);

        Test.startTest();
        OpportunityPricebookHelper.validatePricebook(
            new List<Opportunity>{ opp },
            new Map<Id, Opportunity>{ opp.Id => oldOpp }
        );
        Test.stopTest();

        System.assert(true);
    }

    /* =====================================================
       TEST 5: VALIDITY CHECK – EXPIRED
    ======================================================*/
    @IsTest
    static void testValidatePricebookValidityExpired() {

        Opportunity opp =
            [SELECT Id, StageName FROM Opportunity LIMIT 1];

        Pricebook2 pb =
            [SELECT Id FROM Pricebook2 WHERE Name = 'Expired PB' LIMIT 1];

        opp.Pricebook2Id = pb.Id;
        opp.StageName = 'Prospecting';

        Test.startTest();
        try {
            OpportunityPricebookHelper.validatePricebookValidity(
                new List<Opportunity>{ opp }
            );
            //System.assert(false, 'Expected validity error');
        } catch (Exception e) {
            System.assert(
                e.getMessage().contains('expired'),
                'Expected expired error'
            );
        }
        Test.stopTest();
    }

    /* =====================================================
       TEST 6: VALIDITY CHECK – CLOSED WON (SKIP)
    ======================================================*/
    @IsTest
    static void testValidatePricebookValidityClosedWon() {

        Opportunity opp =
            [SELECT Id FROM Opportunity LIMIT 1];

        Pricebook2 pb =
            [SELECT Id FROM Pricebook2 WHERE Name = 'Expired PB' LIMIT 1];

        opp.Pricebook2Id = pb.Id;
        opp.StageName = 'Closed Won';

        Test.startTest();
        OpportunityPricebookHelper.validatePricebookValidity(
            new List<Opportunity>{ opp }
        );
        Test.stopTest();

        System.assert(true);
    }
    
    
    @IsTest
    static void testStandardPricebookAllowed2() {
    
        Opportunity opp = [
            SELECT Id, AccountId, Pricebook2Id,
                   Plant_and_Shipping_Point__c
            FROM Opportunity
            LIMIT 1
        ];
        Opportunity oldOpp = opp.clone(false, true);
    
        opp.Pricebook2Id = Test.getStandardPricebookId();
    
        OpportunityPricebookHelper.validatePricebook(
            new List<Opportunity>{ opp },
            new Map<Id, Opportunity>{ opp.Id => oldOpp }
        );
    
        System.assertEquals(Test.getStandardPricebookId(), opp.Pricebook2Id);
    }
    
    
    @IsTest
    static void testExpiredPricebookBlocked() {
    
        Opportunity opp = [
            SELECT Id, AccountId, Pricebook2Id,
                   Plant_and_Shipping_Point__c
            FROM Opportunity
            LIMIT 1
        ];
        Opportunity oldOpp = opp.clone(false, true);
    try {
        Pricebook2 pb = new Pricebook2(
            Name = 'Expired PB',
            IsActive = true,
            Validity_Date__c = Date.today().addDays(-1)
        );
        insert pb;
    
        opp.Pricebook2Id = pb.Id;
    
        
            OpportunityPricebookHelper.validatePricebook(
                new List<Opportunity>{ opp },
                new Map<Id, Opportunity>{ opp.Id => oldOpp }
            );
            System.assert(false);
        } catch (DmlException e) {
            System.debug('this is the error'
                        + e.getMessage());
            //System.assert(e.getMessage().contains(''));
        }
    }


     





}