trigger SurveyTrigger on Survey__c (before insert, after insert) {

    if (Trigger.isBefore && Trigger.isInsert) {
        for (Survey__c s : Trigger.new) {
            if (String.isBlank(s.Unique_ID__c)) {
                s.Unique_ID__c = UUIDGenerator.generateUUID();
            }
            if(string.isblank(s.Otp_Verification__c)){
                s.Otp_Verification__c = UUIDGenerator.generateOTP();
            }
        }
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        List<Id> surveyIds = new List<Id>();
        for (Survey__c s : Trigger.new) {
            surveyIds.add(s.Id);
        }
        SurveyService.updateSurveyUrlsWithCommunityBase(surveyIds);
    }
}