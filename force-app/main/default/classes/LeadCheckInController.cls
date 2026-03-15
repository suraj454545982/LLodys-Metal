public   class LeadCheckInController {
    @AuraEnabled
     public static void updateLocation(Id leadId, Decimal latitude, Decimal longitude) {
        Lead l = [SELECT Id FROM Lead WHERE Id = :leadId LIMIT 1];
        l.Location__Latitude__s = latitude;
        l.Location__Longitude__s = longitude;
        update l;
    }
}