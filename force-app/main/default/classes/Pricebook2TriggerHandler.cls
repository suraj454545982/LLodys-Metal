public class Pricebook2TriggerHandler {

    public static void afterUpdate(
        List<Pricebook2> newList,
        Map<Id, Pricebook2> oldMap
    ) {

        if (newList == null || newList.isEmpty() || oldMap == null) {
            return;
        }

        Map<Id, Date> pbValidityMap = new Map<Id, Date>();

        for (Pricebook2 pb : newList) {

            if (pb == null || pb.Id == null) {
                continue;
            }

            Pricebook2 oldPb = oldMap.get(pb.Id);
            if (oldPb == null) {
                continue;
            }

            // Detect change (null-safe)
            if (pb.Validity_Date__c != oldPb.Validity_Date__c) {
                pbValidityMap.put(pb.Id, pb.Validity_Date__c);
            }
        }

        if (pbValidityMap.isEmpty()) {
            return;
        }

        List<PricebookEntry> pbeList = [
            SELECT Id, Pricebook2Id, Validity_Date__c
            FROM PricebookEntry
            WHERE Pricebook2Id IN :pbValidityMap.keySet()
        ];

        if (pbeList == null || pbeList.isEmpty()) {
            return;
        }

        List<PricebookEntry> pbeToUpdate = new List<PricebookEntry>();

        for (PricebookEntry pbe : pbeList) {

            if (pbe == null || pbe.Id == null || pbe.Pricebook2Id == null) {
                continue;
            }

            // Can be null – allowed
            pbe.Validity_Date__c = pbValidityMap.get(pbe.Pricebook2Id);
            pbeToUpdate.add(pbe);
        }

        if (!pbeToUpdate.isEmpty()) {
            update pbeToUpdate;
        }
    }
}