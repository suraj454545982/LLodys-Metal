public without sharing class CaseHandler {

    /* =========================================================
       BEFORE INSERT - CASE NUMBER
    ========================================================= */
    public static void beforeInsertHandler(List<Case> newCases) {
        // Fetch last generated case number
        List<Case> lastCases = [
            SELECT Case_No__c
            FROM Case
            WHERE Case_No__c != null
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        Long lastNumber;

        if (!lastCases.isEmpty() && String.isNotBlank(lastCases[0].Case_No__c)) {
            lastNumber = Long.valueOf(lastCases[0].Case_No__c);
        } else {
            // Fallback start value (MUST be like 3000000302)
            lastNumber = Long.valueOf(Label.Case_Number_Label);
        }

        // Assign incremental numbers
        for (Case c : newCases) {
            lastNumber++;
            c.Case_No__c = String.valueOf(lastNumber);
        }
    }

    /* =========================================================
       ASSIGN CASES
    ========================================================= */
    public static void assignCases(
        List<Case> cases,
        Map<Id, Case> oldCases,
        Boolean isInsert
    ) {
        Map<String, Id> queueMap = getQueueIds();

        for (Case c : cases) {

            /* ==========================
               INSERT
            ========================== */
            if (isInsert) {

                // Email-origin case (no category)
                if (c.Origin == 'Email' && c.Category__c == null) {
                    c.OwnerId = queueMap.get('Email'); // Queue itself
                    continue; // Skip category logic
                }

                // Web-origin / Category case
                if (c.Origin == 'Web' && c.Category__c != null) {
                    Id queueId = queueMap.get(c.Category__c);
                    if (queueId != null) {
                        Id userId = getAnyUserFromQueue(queueId);
                        if (userId != null) {
                            c.OwnerId = userId;
                        }
                    }
                    continue;
                }
            }

            /* ==========================
               UPDATE
            ========================== */
            if (!isInsert && oldCases != null) {

                Case oldCase = oldCases.get(c.Id);
                if (oldCase == null) continue;

                // Only if category changed or for Web-origin
                if (c.Category__c != oldCase.Category__c || c.Origin == 'Web') {
                    Id queueId = queueMap.get(c.Category__c);
                    if (queueId != null) {
                        Id userId = getAnyUserFromQueue(queueId);
                        if (userId != null) {
                            c.OwnerId = userId;
                        }
                    }
                }
            }
        }
    }

    /* =========================================================
       AFTER INSERT → EMAIL + NOTIFICATION
    ========================================================= */
    public static void sendNotificationsAfterInsert(List<Case> cases) {
        for (Case c : cases) {

            // Email-origin queue case → send to all users in queue
            if (c.Origin == 'Email' && c.Category__c == null) {
                sendEmailAndNotificationToQueueUsers(c.OwnerId, c);
            } else if (c.Origin == 'Web' && c.Category__c != null) {
                sendCaseEmail(c);
                sendCaseCustomNotification(c, c.OwnerId);
            }
        }
    }

    /* =========================================================
       AFTER UPDATE → EMAIL + NOTIFICATION (OWNER CHANGE)
    ========================================================= */
    public static void sendNotificationsAfterOwnerChange(
        List<Case> newCases,
        Map<Id, Case> oldMap
    ) {
        for (Case c : newCases) {
            Case oldCase = oldMap.get(c.Id);
            if (oldCase == null || c.OwnerId == oldCase.OwnerId) continue;

            // Email-origin queue case → send to all users in queue
            if (c.Origin == 'Email' && c.Category__c == null) {
                sendEmailAndNotificationToQueueUsers(c.OwnerId, c);
            } else {
                sendCaseEmail(c);
                sendCaseCustomNotification(c, c.OwnerId);
            }
        }
    }

    /* =========================================================
       EMAIL + NOTIFICATION TO ALL USERS IN QUEUE
    ========================================================= */
    private static void sendEmailAndNotificationToQueueUsers(Id queueId, Case c) {
        Map<Id, List<Id>> queueUsers = getUsersFromQueues(new Set<Id>{queueId});
        if (!queueUsers.containsKey(queueId)) return;

        List<Id> userIds = queueUsers.get(queueId);
        for (Id userId : userIds) {
            sendCaseEmail(c, userId);
            sendCaseCustomNotification(c, userId);
        }
    }

    /* =========================================================
       EMAIL USING TEMPLATE
    ========================================================= */
    private static void sendCaseEmail(Case caseRecord) {
        sendCaseEmail(caseRecord, caseRecord.OwnerId);
    }

    private static void sendCaseEmail(Case caseRecord, Id ownerId) {

        EmailTemplate template = [
            SELECT HtmlValue, Subject
            FROM EmailTemplate
            WHERE DeveloperName = 'Case_Creation_Email_to_Assigned_User'
            LIMIT 1
        ];

        User owner = [SELECT Id, FirstName, LastName, Email FROM User WHERE Id = :ownerId];
        if (owner == null || String.isBlank(owner.Email)) return;

        String fullName = ((owner.FirstName != null ? owner.FirstName : '') + ' ' +
                           (owner.LastName != null ? owner.LastName : '')).trim();

        String htmlBody = template.HtmlValue;
        String subject = template.Subject + caseRecord.Case_No__c +
                         ' - ' + (caseRecord.Account != null ? caseRecord.Account.Name : '');

        htmlBody = htmlBody.replace('{!Case.OwnerFullName}', fullName);
        htmlBody = htmlBody.replace('{!Case.Subject}', caseRecord.Subject != null ? caseRecord.Subject : '');
        htmlBody = htmlBody.replace('{!Case.Case_No__c}', caseRecord.Case_No__c != null ? caseRecord.Case_No__c : '');
        htmlBody = htmlBody.replace('{!Case.SuppliedEmail}', caseRecord.SuppliedEmail != null ? caseRecord.SuppliedEmail : '');
        htmlBody = htmlBody.replace('{!Case.Origin}', caseRecord.Origin != null ? caseRecord.Origin : '');
        htmlBody = htmlBody.replace('{!Case.Description}', caseRecord.Description != null ? caseRecord.Description : '');
        htmlBody = htmlBody.replace('{!Case.Url__c}', caseRecord.Url__c != null ? caseRecord.Url__c : '');

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ owner.Email });
        mail.setSaveAsActivity(false);
        mail.setSubject(subject);
        mail.setHtmlBody(htmlBody);

        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail }, false);
    }

    /* =========================================================
       CUSTOM NOTIFICATION
    ========================================================= */
    private static void sendCaseCustomNotification(Case caseRecord, Id ownerId) {

        CustomNotificationType cnType = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Case'
            LIMIT 1
        ];

        Messaging.CustomNotification customNotificationObj = new Messaging.CustomNotification();

        String body =
            'Case Number: ' + (caseRecord.Case_No__c != null ? caseRecord.Case_No__c : '') + '\n' +
            'Subject: ' + (caseRecord.Subject != null ? caseRecord.Subject : '') + '\n' +
            'Origin: ' + (caseRecord.Origin != null ? caseRecord.Origin : '') + '\n' +
            'Email: ' + (caseRecord.SuppliedEmail != null ? caseRecord.SuppliedEmail : '') + '\n' +
            'Description: ' + (caseRecord.Description != null ? caseRecord.Description : '');

        customNotificationObj.setTitle('New Case Assigned');
        customNotificationObj.setBody(body);
        customNotificationObj.setNotificationTypeId(cnType.Id);
        customNotificationObj.setSenderId(UserInfo.getUserId());
        customNotificationObj.setTargetId(caseRecord.Id);

        // expects Set<String>
        customNotificationObj.send(new Set<String>{ String.valueOf(ownerId) });
    }

    /* =========================================================
       QUEUE IDS
    ========================================================= */
    private static Map<String, Id> getQueueIds() {

        Map<String, Id> mapQueue = new Map<String, Id>();

        for (Group g : [
            SELECT Id, Name
            FROM Group
            WHERE Type = 'Queue'
            AND Name IN (
                'Email_Queue',
                'DRIQueue_Case',
                'IronOreQueue_Case',
                'PelletQueue_Case'
            )
        ]) {
            if (g.Name == 'Email_Queue') {
                mapQueue.put('Email', g.Id);
            } else if (g.Name == 'DRIQueue_Case') {
                mapQueue.put('DRI', g.Id);
            } else if (g.Name == 'IronOreQueue_Case') {
                mapQueue.put('Iron Ore', g.Id);
            } else if (g.Name == 'PelletQueue_Case') {
                mapQueue.put('Iron Ore Pellet', g.Id);
            }
        }
        return mapQueue;
    }

    /* =========================================================
       GET ONE USER FROM QUEUE
    ========================================================= */
    private static Id getAnyUserFromQueue(Id queueId) {
        List<GroupMember> gms = [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :queueId LIMIT 1];
        return gms.isEmpty() ? null : gms[0].UserOrGroupId;
    }

    /* =========================================================
       GET ALL USERS FROM QUEUE
    ========================================================= */
    private static Map<Id, List<Id>> getUsersFromQueues(Set<Id> queueIds) {
        Map<Id, List<Id>> result = new Map<Id, List<Id>>();
        for (GroupMember gm : [SELECT GroupId, UserOrGroupId FROM GroupMember WHERE GroupId IN :queueIds]) {
            if (!result.containsKey(gm.GroupId)) {
                result.put(gm.GroupId, new List<Id>());
            }
            result.get(gm.GroupId).add(gm.UserOrGroupId);
        }
        return result;
    }
}