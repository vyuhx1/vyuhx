public without sharing class LogVisitActivityAction {

    public class Request {
        @InvocableVariable(label='Visit Id' description='Id of the Visit record to log activity against' required=true)
        public String visitId;

        @InvocableVariable(label='Action' description='What to do: start (marks InProgress, captures now as start time), end (marks Completed, captures now as end time), update notes (attaches a note only)' required=true)
        public String action;

        @InvocableVariable(label='Visit Notes' description='Optional note body to attach to the visit')
        public String visitNotes;
    }

    public class Result {
        @InvocableVariable(label='Visit Output' description='Confirmation message describing what was done')
        public String visitOutput;
    }

    @InvocableMethod(
        label='Visit Activity Log'
        description='Logs activity against a Visit using an action keyword: "start" captures the current time as ActualVisitStartTime and sets status to InProgress; "end" captures the current time as ActualVisitEndTime and sets status to Completed; "update notes" attaches a note to the visit without changing times or status.'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(processRequest(req));
        }
        return results;
    }

    // ── Core Logic ─────────────────────────────────────────────
    private static Result processRequest(Request req) {
        Result res = new Result();

        // Step 1 – Validate action
        String action = String.isBlank(req.action) ? '' : req.action.trim().toLowerCase();
        if (action != 'start' && action != 'end' && action != 'update notes') {
            res.visitOutput = 'Invalid action "' + req.action + '". Use: start, end, or update notes.';
            return res;
        }

        // Step 2 – Query the Visit record
        List<Visit> visits = [
            SELECT Id, Status, ActualVisitStartTime, ActualVisitEndTime
            FROM   Visit
            WHERE  Id = :req.visitId
            LIMIT  1
        ];

        if (visits.isEmpty()) {
            res.visitOutput = 'Visit not found.';
            return res;
        }

        Visit v = visits[0];

        // Step 3 – Attach note if provided (applies to any action)
        if (String.isNotBlank(req.visitNotes)) {
            createNote(req.visitId, req.visitNotes, 'Visit Note');
        }

        // Step 4 – Execute action
        DateTime now = DateTime.now();

        if (action == 'start') {
            if (v.Status != 'Planned') {
                res.visitOutput = 'Cannot start visit — current status is ' + v.Status + '.';
                return res;
            }
            update new Visit(
                Id                   = v.Id,
                Status               = 'InProgress',
                ActualVisitStartTime = now
            );
            res.visitOutput = 'Visit started at ' + now.format('dd MMM yyyy, HH:mm', 'Asia/Kolkata') + ' IST. Status set to In Progress.';

        } else if (action == 'end') {
            if (v.Status != 'InProgress') {
                res.visitOutput = 'Cannot end visit — current status is ' + v.Status + '. Please start the visit first.';
                return res;
            }
            update new Visit(
                Id                 = v.Id,
                Status             = 'Completed',
                ActualVisitEndTime = now
            );
            res.visitOutput = 'Visit completed at ' + now.format('dd MMM yyyy, HH:mm', 'Asia/Kolkata') + ' IST. Status set to Completed.';

        } else {
            // update notes — note already attached above, no record update needed
            if (String.isBlank(req.visitNotes)) {
                res.visitOutput = 'No notes provided. Nothing was updated.';
            } else {
                res.visitOutput = 'Note added to the visit successfully.';
            }
        }

        return res;
    }

    // ── Note Creation ──────────────────────────────────────────
    private static void createNote(String visitId, String noteBody, String noteTitle) {
        ContentNote cn = new ContentNote();
        cn.Title       = String.isBlank(noteTitle) ? 'Visit Note' : noteTitle;
        cn.Content     = Blob.valueOf(noteBody.escapeHtml4());
        insert cn;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId   = cn.Id;
        cdl.LinkedEntityId      = visitId;
        cdl.ShareType           = 'V';
        cdl.Visibility          = 'AllUsers';
        insert cdl;
    }
}