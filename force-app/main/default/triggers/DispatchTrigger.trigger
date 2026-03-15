trigger DispatchTrigger on Dispatch__c (before insert) {
    /*if(Trigger.isInsert && Trigger.isBefore){
        SAPExternalHandler.PopulateExternalIdforDispatch(Trigger.new);
    }*/
}