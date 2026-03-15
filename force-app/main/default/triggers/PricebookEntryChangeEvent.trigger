trigger PricebookEntryChangeEvent on PricebookEntryChangeEvent (after insert) {
    System.debug(' PricebookEntryChangeEventTrigger fired...');
    System.enqueueJob(new PricebookEntryCDCQueueable(Trigger.new));
}