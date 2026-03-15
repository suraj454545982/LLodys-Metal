trigger InventoryTrigger on Inventory__c (before insert) {
    /*if(Trigger.isInsert && Trigger.isBefore){
        SAPExternalHandler.PopulateExternalIdforInventory(Trigger.new);
    }*/
}