trigger AddressTrigger on Address__c (after update) {
    
    if(Trigger.isAfter && Trigger.isUpdate){
        AddressTriggerHelper.handleShippingAddressUpdate(Trigger.new,Trigger.oldMap);
    }
    
}