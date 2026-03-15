/**
 * Trigger on Product2 object to handle updates to Material_Blocked__c field.
 * This trigger delegates logic to ProductTriggerHandler for before and after update events.
 * When Material_Blocked__c changes to 'Yes', it deactivates the Product and related PricebookEntries.
 * When changed to 'No', it activates them.
 * @author Simon Christopher
 * @date 2025-11-20
 */
trigger ProductTrigger on Product2 (before update, after update) {
    ProductTriggerHandler handler = new ProductTriggerHandler();
    
    if (Trigger.isBefore && Trigger.isUpdate) {
        handler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        handler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}