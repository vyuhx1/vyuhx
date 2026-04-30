public without sharing class GetMyVisitsAction {

    public class Request {
        @InvocableVariable(
            label='Status Filter'
            description='Optional: Planned, InProgress, Completed, Cancelled. Leave blank to return all visits.'
        )
        public String statusFilter;
    }

    public class Result {
        @InvocableVariable(
            label='Visit Summary'
            description='Plain-text summary of visits assigned to the running user, ready for the agent to speak back.'
        )
        public String visitSummary;

        @InvocableVariable(
            label='Visit Response'
            description='Structured VisitResponseDTO rendered by the My Visits Lightning Type card (myVisitDetails LWC).'
        )
        public VisitResponseDTO visitResponse;
    }

    @InvocableMethod(
        label='Get My Visits'
        description='Returns visit details for the currently logged-in user. Produces both a plain-text summary and a rich VisitResponseDTO for the Lightning Type card renderer.'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(buildResult(req));
        }
        return results;
    }

    // ── Core Logic ─────────────────────────────────────────────
    private static Result buildResult(Request req) {
        Result res = new Result();
        Id userId  = UserInfo.getUserId();

        String filter = String.isBlank(req.statusFilter) ? null : req.statusFilter.trim();

        // ── Step 1: Query visits for current user ─────────────
        List<Visit> visits;
        if (filter != null) {
            visits = [
                SELECT Id, ContextId, Context.Name,
                       VisitorId, Visitor.Name,
                       Status, VisitPriority,
                       PlannedVisitStartTime, PlannedVisitEndTime,
                       ActualVisitStartTime,  ActualVisitEndTime,
                       StatusRemarks, InstructionDescription
                FROM   Visit
                WHERE  VisitorId = :userId
                AND    Status    = :filter
                ORDER BY PlannedVisitStartTime ASC NULLS LAST
                LIMIT  20
            ];
        } else {
            visits = [
                SELECT Id, ContextId, Context.Name,
                       VisitorId, Visitor.Name,
                       Status, VisitPriority,
                       PlannedVisitStartTime, PlannedVisitEndTime,
                       ActualVisitStartTime,  ActualVisitEndTime,
                       StatusRemarks, InstructionDescription
                FROM   Visit
                WHERE  VisitorId = :userId
                ORDER BY PlannedVisitStartTime ASC NULLS LAST
                LIMIT  20
            ];
        }

        // ── Empty result ──────────────────────────────────────
        if (visits.isEmpty()) {
            String msg = filter != null
                ? 'You have no ' + filter + ' visits assigned to you.'
                : 'You have no visits currently assigned to you.';
            res.visitSummary  = msg;
            res.visitResponse = emptyResponse();
            return res;
        }

        // ── Step 2: Load Sites__c for hierarchy + coordinates ─
        Set<Id> contextIds = new Set<Id>();
        for (Visit v : visits) { if (v.ContextId != null) contextIds.add(v.ContextId); }

        Map<Id, Sites__c> siteMap = new Map<Id, Sites__c>();
        if (!contextIds.isEmpty()) {
            for (Sites__c s : [
                SELECT Id,
                       Retail_Store__r.Name,
                       Retail_Store__r.RetailLocationGroup.Name,
                       Proposed_Site_Location__Latitude__s,
                       Proposed_Site_Location__Longitude__s,
                       Site_Address__Latitude__s,
                       Site_Address__Longitude__s
                FROM   Sites__c
                WHERE  Id IN :contextIds
            ]) { siteMap.put(s.Id, s); }
        }

        // ── Step 3: Load ContentNotes (up to 3 per visit) ─────
        Set<Id> visitIds = new Set<Id>();
        for (Visit v : visits) visitIds.add(v.Id);

        Map<Id, Id> docToVisit = new Map<Id, Id>();
        Set<Id> allDocIds      = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM   ContentDocumentLink
            WHERE  LinkedEntityId IN :visitIds
        ]) {
            docToVisit.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
            allDocIds.add(cdl.ContentDocumentId);
        }

        Map<Id, List<VisitNoteDTO>> visitNotes = new Map<Id, List<VisitNoteDTO>>();
        if (!allDocIds.isEmpty()) {
            for (ContentNote cn : [
                SELECT Id, Title, TextPreview, LastModifiedDate
                FROM   ContentNote
                WHERE  Id IN :allDocIds
                ORDER BY LastModifiedDate DESC
            ]) {
                Id vid = docToVisit.get(cn.Id);
                if (vid == null) continue;
                if (!visitNotes.containsKey(vid)) visitNotes.put(vid, new List<VisitNoteDTO>());
                List<VisitNoteDTO> nl = visitNotes.get(vid);
                if (nl.size() < 3) {
                    VisitNoteDTO nd = new VisitNoteDTO();
                    nd.noteId       = cn.Id;
                    nd.noteTitle    = cn.Title;
                    nd.notePreview  = cn.TextPreview;
                    nd.lastModified = cn.LastModifiedDate != null
                                      ? cn.LastModifiedDate.format('dd MMM yyyy HH:mm') : null;
                    nl.add(nd);
                }
            }
        }

        // ── Step 4: Map to DTOs + build text summary + tally counts ──
        Integer planned = 0, inProgress = 0, completed = 0, cancelled = 0;
        List<VisitDTO> dtoList  = new List<VisitDTO>();
        List<String>   lines    = new List<String>();
        Integer        num      = 1;

        for (Visit v : visits) {
            Sites__c site  = siteMap.get(v.ContextId);

            // — VisitDTO for the card —
            VisitDTO dto       = new VisitDTO();
            dto.visitId        = v.Id;
            dto.siteId         = v.ContextId;
            dto.siteName       = v.Context != null ? v.Context.Name : 'N/A';
            dto.retailStore    = (site != null && site.Retail_Store__r != null)
                                 ? site.Retail_Store__r.Name : null;
            dto.groupName      = (site != null && site.Retail_Store__r != null
                                  && site.Retail_Store__r.RetailLocationGroup != null)
                                 ? site.Retail_Store__r.RetailLocationGroup.Name : null;
            dto.visitorName    = v.Visitor != null ? v.Visitor.Name : 'Unassigned';
            dto.status         = v.Status;
            dto.priority       = v.VisitPriority;
            dto.plannedStart   = v.PlannedVisitStartTime != null
                                 ? v.PlannedVisitStartTime.format('dd MMM yyyy HH:mm') : null;
            dto.plannedEnd     = v.PlannedVisitEndTime   != null
                                 ? v.PlannedVisitEndTime.format('dd MMM yyyy HH:mm')   : null;
            dto.actualStart    = v.ActualVisitStartTime  != null
                                 ? v.ActualVisitStartTime.format('dd MMM yyyy HH:mm')  : null;
            dto.actualEnd      = v.ActualVisitEndTime    != null
                                 ? v.ActualVisitEndTime.format('dd MMM yyyy HH:mm')    : null;
            dto.statusRemarks  = v.StatusRemarks;
            dto.instructions   = v.InstructionDescription;
            if (site != null) {
                dto.latitude  = site.Proposed_Site_Location__Latitude__s  != null
                                ? site.Proposed_Site_Location__Latitude__s
                                : site.Site_Address__Latitude__s;
                dto.longitude = site.Proposed_Site_Location__Longitude__s != null
                                ? site.Proposed_Site_Location__Longitude__s
                                : site.Site_Address__Longitude__s;
            }
            dto.notes = visitNotes.containsKey(v.Id) ? visitNotes.get(v.Id) : new List<VisitNoteDTO>();
            dtoList.add(dto);

            // — status tally —
            String s = (v.Status ?? '').toLowerCase();
            if      (s == 'planned')    planned++;
            else if (s == 'inprogress') inProgress++;
            else if (s == 'completed')  completed++;
            else if (s == 'cancelled')  cancelled++;

            // — text summary line —
            String priority = String.isNotBlank(v.VisitPriority) ? ' | Priority: ' + v.VisitPriority : '';
            String timing   = '';
            if (v.ActualVisitStartTime != null && v.ActualVisitEndTime != null) {
                timing = ' | Started: ' + formatDt(v.ActualVisitStartTime)
                       + ' | Ended: '   + formatDt(v.ActualVisitEndTime);
            } else if (v.ActualVisitStartTime != null) {
                timing = ' | Started: ' + formatDt(v.ActualVisitStartTime);
            } else if (v.PlannedVisitStartTime != null) {
                timing = ' | Planned: ' + formatDt(v.PlannedVisitStartTime);
                if (v.PlannedVisitEndTime != null) timing += ' → ' + formatDt(v.PlannedVisitEndTime);
            }
            lines.add(num++ + '. ' + dto.siteName + ' – ' + (v.Status ?? 'Unknown') + priority + timing);
        }

        // ── Step 5: Assemble result ───────────────────────────
        String heading = filter != null
            ? 'You have ' + visits.size() + ' ' + filter + ' visit(s):\n\n'
            : 'You have ' + visits.size() + ' visit(s) assigned to you:\n\n';
        res.visitSummary = heading + String.join(lines, '\n');

        VisitResponseDTO response = new VisitResponseDTO();
        response.visits          = dtoList;
        response.plannedCount    = planned;
        response.inProgressCount = inProgress;
        response.completedCount  = completed;
        response.cancelledCount  = cancelled;
        res.visitResponse        = response;

        return res;
    }

    // ── Helpers ────────────────────────────────────────────────
    private static VisitResponseDTO emptyResponse() {
        VisitResponseDTO r = new VisitResponseDTO();
        r.visits          = new List<VisitDTO>();
        r.plannedCount    = 0;
        r.inProgressCount = 0;
        r.completedCount  = 0;
        r.cancelledCount  = 0;
        return r;
    }

    private static String formatDt(DateTime dt) {
        return dt.format('dd MMM yyyy, HH:mm');
    }
}