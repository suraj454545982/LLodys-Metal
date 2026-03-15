trigger EventTrigger on Event (after insert, after update) {
     List<Event> eventsToProcess = new List<Event>();
    for (Event e : Trigger.new) {
        if (e.Joining_Through__c != null &&
            (e.Joining_Through__c == 'Online' || e.Joining_Through__c == 'Offline')) {
            eventsToProcess.add(e);
        }
    }

    if (!eventsToProcess.isEmpty()) {
        Emailtest.sendOfflineJoiningEmails(eventsToProcess);
    }
}