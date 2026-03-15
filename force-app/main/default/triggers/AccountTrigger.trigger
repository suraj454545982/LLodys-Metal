trigger AccountTrigger on Account (before insert, before update, after insert, after update, before delete, after delete, after undelete) {
    {
        if (Trigger.isBefore && Trigger.isUpdate) {
            AccountTriggerHelper.validateRejectionComments(Trigger.new, Trigger.oldMap);
            AccountTriggerHelper.validateReassignmentComments(Trigger.new, Trigger.oldMap);
        }
        
        //Happens @before Trigger
        if (Trigger.isBefore && Trigger.isUpdate) {
            System.debug('markSensitiveFlag Called');
            AccountTriggerHelper.markSensitiveFlag(Trigger.new, Trigger.oldMap);
        }
        
        if (Trigger.isBefore && Trigger.isUpdate) {
            AccountTriggerHelper.prepareUpdateFlags(
                Trigger.new,
                Trigger.oldMap
            );
        }
        
        if (Trigger.isAfter && Trigger.isUpdate) {
            AccountTriggerHelper.processSAPSync(Trigger.new, Trigger.oldMap);
        }
    }
}