trigger LeadTrigger on Lead (before insert, before update, after insert, after update,
                             before delete, after delete, after undelete) 
{
     LeadTriggerHandler handler = new LeadTriggerHandler();
    
    if (Trigger.isBefore && Trigger.isInsert) {
        handler.assignLeads(Trigger.new, null, true);
        //handler.validateAccountBlock(Trigger.new);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        handler.assignLeads(Trigger.new,Trigger.oldmap,false);
    }
    if (Trigger.isAfter && Trigger.isInsert) {
        System.debug('Lead Creation');
        handler.handleWebsiteLeads(Trigger.new);
        handler.assignLeadOwnersAfterInsert(Trigger.new);
    }
    //DynamicAccountRelatedObjectHandler.preventActionsOnRelatedObjects(Trigger.new, Trigger.isDelete ? 'delete' : 'insert/update');
    if (Trigger.isAfter && Trigger.isUpdate) {
        handler.handleAfterUpdate(Trigger.new, Trigger.oldMap);    
        //handler.handleUserInvite(Trigger.new, Trigger.oldMap);      
        for (Lead ld : Trigger.new) {
            Lead oldLd = Trigger.oldMap.get(ld.Id);
            if (ld.OwnerId != oldLd.OwnerId && String.valueOf(ld.OwnerId).startsWith('005')) {
                LeadTriggerHandler.sendEmailToNewOwnerWithTemplate(ld.OwnerId, ld.Id);
            }
        }
    }
    
}