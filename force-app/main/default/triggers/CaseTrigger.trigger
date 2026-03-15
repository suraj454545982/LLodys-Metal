trigger CaseTrigger on Case (
    before insert, before update,
    after insert, after update
) {

    // ==========================
    // BEFORE INSERT
    // ==========================
    if (Trigger.isBefore && Trigger.isInsert) {
        // Generate Case Number
        CaseHandler.beforeInsertHandler(Trigger.new);

        // Assign owners
        CaseHandler.assignCases(Trigger.new, Trigger.oldMap, true);
    }

    // ==========================
    // BEFORE UPDATE
    // ==========================
    if (Trigger.isBefore && Trigger.isUpdate) {
        // Assign owners if category changed
        CaseHandler.assignCases(Trigger.new, Trigger.oldMap, false);
    }

    // ==========================
    // AFTER INSERT
    // ==========================
    if (Trigger.isAfter && Trigger.isInsert) {
        CaseHandler.sendNotificationsAfterInsert(Trigger.new);
    }

    // ==========================
    // AFTER UPDATE
    // ==========================
    if (Trigger.isAfter && Trigger.isUpdate) {
        CaseHandler.sendNotificationsAfterOwnerChange(Trigger.new, Trigger.oldMap);
    }
}