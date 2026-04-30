public without sharing class VisitNotificationService {

    // Send a notification for a single specific visit
    public static void sendAlertForVisit(Id visitId) {
        CustomNotificationType notifType = [
            SELECT Id FROM CustomNotificationType
            WHERE DeveloperName = 'Visit_Alert'
            LIMIT 1
        ];

        Visit v = [
            SELECT Id, VisitorId, Visitor.Name,
                   Context.Name, PlannedVisitStartTime, Status
            FROM   Visit
            WHERE  Id = :visitId
            LIMIT  1
        ];

        if (v.VisitorId == null) return;

        Datetime now = Datetime.now();
        Boolean isOverdue = v.PlannedVisitStartTime != null && v.PlannedVisitStartTime < now;

        String title = isOverdue
            ? 'Overdue Visit: ' + (v.Context != null ? v.Context.Name : 'Site')
            : 'Visit Due Soon: ' + (v.Context != null ? v.Context.Name : 'Site');
        String body = isOverdue
            ? 'Your visit to ' + (v.Context != null ? v.Context.Name : 'the site')
              + ' was scheduled for ' + v.PlannedVisitStartTime.format('dd MMM yyyy HH:mm')
              + ' and is now overdue. Please update the visit status.'
            : 'Reminder: your visit to ' + (v.Context != null ? v.Context.Name : 'the site')
              + ' is scheduled for ' + v.PlannedVisitStartTime.format('dd MMM yyyy HH:mm')
              + '. Make sure you are prepared.';

        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setNotificationTypeId(notifType.Id);
        notification.setTargetId(v.Id);
        notification.setTitle(title);
        notification.setBody(body);
        notification.send(new Set<String>{ v.VisitorId });
    }

    // Called by the scheduler — finds overdue and due-soon visits and notifies surveyors
    public static void sendVisitAlerts() {
        CustomNotificationType notifType = [
            SELECT Id FROM CustomNotificationType
            WHERE DeveloperName = 'Visit_Alert'
            LIMIT 1
        ];

        Datetime now       = Datetime.now();
        Datetime soonLimit = now.addHours(72); // "due soon" = within 3 days

        List<Visit> visits = [
            SELECT Id, VisitorId, Visitor.Name,
                   Context.Name, PlannedVisitStartTime, Status
            FROM   Visit
            WHERE  Status = 'Planned'
            AND    VisitorId != null
            AND    PlannedVisitStartTime != null
            AND    PlannedVisitStartTime <= :soonLimit
            ORDER BY PlannedVisitStartTime ASC
            LIMIT  200
        ];

        if (visits.isEmpty()) return;

        // Group by VisitorId so we can send one notification per user per visit
        for (Visit v : visits) {
            Boolean isOverdue = v.PlannedVisitStartTime < now;
            Boolean isDueSoon = !isOverdue;

            String title;
            String body;
            if (isOverdue) {
                title = 'Overdue Visit: ' + (v.Context != null ? v.Context.Name : 'Site');
                body  = 'Your visit to ' + (v.Context != null ? v.Context.Name : 'the site')
                      + ' was scheduled for '
                      + v.PlannedVisitStartTime.format('dd MMM yyyy HH:mm')
                      + ' and is now overdue. Please update the visit status.';
            } else {
                title = 'Visit Due Soon: ' + (v.Context != null ? v.Context.Name : 'Site');
                body  = 'Reminder: your visit to ' + (v.Context != null ? v.Context.Name : 'the site')
                      + ' is scheduled for '
                      + v.PlannedVisitStartTime.format('dd MMM yyyy HH:mm')
                      + '. Make sure you are prepared.';
            }

            try {
                Messaging.CustomNotification notification = new Messaging.CustomNotification();
                notification.setNotificationTypeId(notifType.Id);
                notification.setTargetId(v.Id);        // clicking opens the Visit record
                notification.setTitle(title);
                notification.setBody(body);
                notification.send(new Set<String>{ v.VisitorId });
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'VisitNotificationService: failed to notify visitor ' + v.VisitorId
                    + ' for visit ' + v.Id + ' — ' + e.getMessage());
            }
        }
    }
}