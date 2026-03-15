trigger Pricebook2Trigger on Pricebook2 (after update) {

    if (Trigger.new == null || Trigger.new.isEmpty() || Trigger.oldMap == null) {
        return;
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        Pricebook2TriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}