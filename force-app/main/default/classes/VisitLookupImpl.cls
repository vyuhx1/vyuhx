public class VisitLookupImpl implements IVisitLookup {

    public List<VisitDTO> lookupVisits(String siteName, String retailStoreName,
                                       String retailStoreGroupName, String statusFilter,
                                       String dateFilter) {

        // ── Step 1: Resolve context IDs based on hierarchy level ─────────────────
        // Visits link to Sites__c via ContextId.
        // For RetailStore / RetailStoreGroup we first find matching Site IDs.
        Set<Id> siteIds = new Set<Id>();
        Boolean filterBySiteIds = false;
        String siteNameLike = null;

        if (String.isNotBlank(retailStoreGroupName)) {
            filterBySiteIds = true;
            String key = '%' + retailStoreGroupName + '%';
            for (Sites__c s : [
                SELECT Id FROM Sites__c
                WHERE Retail_Store__r.RetailLocationGroup.Name LIKE :key
            ]) { siteIds.add(s.Id); }

        } else if (String.isNotBlank(retailStoreName)) {
            filterBySiteIds = true;
            String key = '%' + retailStoreName + '%';
            for (Sites__c s : [
                SELECT Id FROM Sites__c
                WHERE Retail_Store__r.Name LIKE :key
            ]) { siteIds.add(s.Id); }

        } else if (String.isNotBlank(siteName)) {
            siteNameLike = '%' + siteName + '%';
        }

        // If a hierarchy filter was given but no sites matched, return empty
        if (filterBySiteIds && siteIds.isEmpty()) {
            return new List<VisitDTO>();
        }

        // ── Step 2: Build Visit date range for Completed-by-date filter ──────────
        Datetime dateStart = null;
        Datetime dateEnd   = null;
        if (String.isNotBlank(dateFilter)) {
            Date d;
            String df = dateFilter.trim().toLowerCase();
            if (df == 'today') {
                d = Date.today();
            } else if (df == 'yesterday') {
                d = Date.today().addDays(-1);
            } else {
                // Expect dd-MM-yyyy
                try {
                    List<String> parts = dateFilter.trim().split('-');
                    d = Date.newInstance(Integer.valueOf(parts[2]),
                                        Integer.valueOf(parts[1]),
                                        Integer.valueOf(parts[0]));
                } catch (Exception e) { d = null; }
            }
            if (d != null) {
                dateStart = Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
                dateEnd   = Datetime.newInstance(d.addDays(1), Time.newInstance(0, 0, 0, 0));
            }
        }

        // ── Step 3: Query Visits with dynamic conditions ─────────────────────────
        // Context on Visit is a polymorphic lookup — custom relationship traversal
        // (Retail_Store__r) is blocked through it. We query Sites__c separately.
        String soql =
            'SELECT Id, ContextId, Context.Name,' +
            '       VisitorId, Visitor.Name,' +
            '       Status, VisitPriority,' +
            '       PlannedVisitStartTime, PlannedVisitEndTime,' +
            '       ActualVisitStartTime, ActualVisitEndTime,' +
            '       StatusRemarks, InstructionDescription' +
            ' FROM Visit' +
            ' WHERE Id != null';

        if (filterBySiteIds) {
            soql += ' AND ContextId IN :siteIds';
        } else if (siteNameLike != null) {
            soql += ' AND Context.Name LIKE :siteNameLike';
        }

        if (String.isNotBlank(statusFilter)) {
            soql += ' AND Status = :statusFilter';
        }

        if (dateStart != null && dateEnd != null) {
            soql += ' AND ActualVisitEndTime >= :dateStart AND ActualVisitEndTime < :dateEnd';
        }

        soql += ' ORDER BY PlannedVisitStartTime DESC LIMIT 20';

        List<Visit> visits = Database.query(soql);

        // ── Step 3b: Separately query Sites__c for retailStore / groupName ───────
        // (Cannot traverse Retail_Store__r through polymorphic Context relationship)
        Set<Id> contextIds = new Set<Id>();
        for (Visit v : visits) { if (v.ContextId != null) contextIds.add(v.ContextId); }

        Map<Id, Sites__c> siteMap = new Map<Id, Sites__c>();
        if (!contextIds.isEmpty()) {
            for (Sites__c s : [
                SELECT Id,
                       Retail_Store__r.Name,
                       Retail_Store__r.RetailLocationGroup.Name,
                       Site_Address__City__s,
                       Site_Address__StateCode__s,
                       Site_Address__PostalCode__s,
                       Site_Address__CountryCode__s,
                       Site_Address__Latitude__s,
                       Site_Address__Longitude__s,
                       Proposed_Site_Location__Latitude__s,
                       Proposed_Site_Location__Longitude__s
                FROM Sites__c
                WHERE Id IN :contextIds
            ]) {
                siteMap.put(s.Id, s);
            }
        }

        // ── Step 4: ContentNote lookup ───────────────────────────────────────────
        Set<Id> visitIds = new Set<Id>();
        for (Visit v : visits) visitIds.add(v.Id);

        Map<Id, Id> docToVisit = new Map<Id, Id>();
        Set<Id> allDocIds      = new Set<Id>();
        if (!visitIds.isEmpty()) {
            for (ContentDocumentLink cdl : [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :visitIds
            ]) {
                docToVisit.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
                allDocIds.add(cdl.ContentDocumentId);
            }
        }

        Map<Id, List<VisitNoteDTO>> visitNotes = new Map<Id, List<VisitNoteDTO>>();
        if (!allDocIds.isEmpty()) {
            for (ContentNote cn : [
                SELECT Id, Title, TextPreview, LastModifiedDate
                FROM ContentNote
                WHERE Id IN :allDocIds
                ORDER BY LastModifiedDate DESC
            ]) {
                Id vid = docToVisit.get(cn.Id);
                if (vid == null) continue;
                if (!visitNotes.containsKey(vid)) {
                    visitNotes.put(vid, new List<VisitNoteDTO>());
                }
                List<VisitNoteDTO> noteList = visitNotes.get(vid);
                if (noteList.size() < 3) {
                    VisitNoteDTO nd = new VisitNoteDTO();
                    nd.noteId       = cn.Id;
                    nd.noteTitle    = cn.Title;
                    nd.notePreview  = cn.TextPreview;
                    nd.lastModified = cn.LastModifiedDate != null
                                      ? cn.LastModifiedDate.format('dd MMM yyyy HH:mm') : null;
                    noteList.add(nd);
                }
            }
        }

        // ── Step 5: Map to DTOs ──────────────────────────────────────────────────
        List<VisitDTO> results = new List<VisitDTO>();
        for (Visit v : visits) {
            VisitDTO dto      = new VisitDTO();
            dto.visitId       = v.Id;
            dto.siteId        = v.ContextId;
            dto.siteName      = v.Context != null ? v.Context.Name : 'N/A';
            Sites__c site     = siteMap.get(v.ContextId);
            dto.retailStore   = (site != null && site.Retail_Store__r != null)
                                ? site.Retail_Store__r.Name : null;
            dto.groupName     = (site != null && site.Retail_Store__r != null
                                 && site.Retail_Store__r.RetailLocationGroup != null)
                                ? site.Retail_Store__r.RetailLocationGroup.Name : null;
            dto.visitorName   = v.Visitor != null ? v.Visitor.Name : 'Unassigned';
            dto.status        = v.Status;
            dto.priority      = v.VisitPriority;
            dto.plannedStart  = v.PlannedVisitStartTime != null
                                ? v.PlannedVisitStartTime.format('dd MMM yyyy HH:mm') : null;
            dto.plannedEnd    = v.PlannedVisitEndTime != null
                                ? v.PlannedVisitEndTime.format('dd MMM yyyy HH:mm')   : null;
            dto.actualStart   = v.ActualVisitStartTime != null
                                ? v.ActualVisitStartTime.format('dd MMM yyyy HH:mm')  : null;
            dto.actualEnd     = v.ActualVisitEndTime != null
                                ? v.ActualVisitEndTime.format('dd MMM yyyy HH:mm')    : null;
            dto.statusRemarks = v.StatusRemarks;
            dto.instructions  = v.InstructionDescription;
            // Store coordinates — client-side JS builds the Maps URL to avoid URL_Redacted
            if (site != null) {
                dto.latitude  = site.Proposed_Site_Location__Latitude__s != null
                                ? site.Proposed_Site_Location__Latitude__s
                                : site.Site_Address__Latitude__s;
                dto.longitude = site.Proposed_Site_Location__Longitude__s != null
                                ? site.Proposed_Site_Location__Longitude__s
                                : site.Site_Address__Longitude__s;
            }
            dto.notes         = visitNotes.containsKey(v.Id)
                                ? visitNotes.get(v.Id) : new List<VisitNoteDTO>();
            results.add(dto);
        }
        return results;
    }

    public Map<String, Integer> countVisits(String siteName, String retailStoreName,
                                             String retailStoreGroupName, String dateFilter) {

        // Reuse same site-ID resolution logic
        Set<Id> siteIds = new Set<Id>();
        Boolean filterBySiteIds = false;
        String siteNameLike = null;

        if (String.isNotBlank(retailStoreGroupName)) {
            filterBySiteIds = true;
            String key = '%' + retailStoreGroupName + '%';
            for (Sites__c s : [
                SELECT Id FROM Sites__c
                WHERE Retail_Store__r.RetailLocationGroup.Name LIKE :key
            ]) { siteIds.add(s.Id); }

        } else if (String.isNotBlank(retailStoreName)) {
            filterBySiteIds = true;
            String key = '%' + retailStoreName + '%';
            for (Sites__c s : [
                SELECT Id FROM Sites__c
                WHERE Retail_Store__r.Name LIKE :key
            ]) { siteIds.add(s.Id); }

        } else if (String.isNotBlank(siteName)) {
            siteNameLike = '%' + siteName + '%';
        }

        if (filterBySiteIds && siteIds.isEmpty()) {
            return new Map<String, Integer>();
        }

        // Date range (same logic as lookupVisits)
        Datetime dateStart = null;
        Datetime dateEnd   = null;
        if (String.isNotBlank(dateFilter)) {
            Date d;
            String df = dateFilter.trim().toLowerCase();
            if (df == 'today') {
                d = Date.today();
            } else if (df == 'yesterday') {
                d = Date.today().addDays(-1);
            } else {
                try {
                    List<String> parts = dateFilter.trim().split('-');
                    d = Date.newInstance(Integer.valueOf(parts[2]),
                                        Integer.valueOf(parts[1]),
                                        Integer.valueOf(parts[0]));
                } catch (Exception e) { d = null; }
            }
            if (d != null) {
                dateStart = Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
                dateEnd   = Datetime.newInstance(d.addDays(1), Time.newInstance(0, 0, 0, 0));
            }
        }

        // Aggregate SOQL — no statusFilter so all statuses are counted
        String countSoql =
            'SELECT Status, COUNT(Id) total' +
            ' FROM Visit' +
            ' WHERE Id != null';

        if (filterBySiteIds) {
            countSoql += ' AND ContextId IN :siteIds';
        } else if (siteNameLike != null) {
            countSoql += ' AND Context.Name LIKE :siteNameLike';
        }

        if (dateStart != null && dateEnd != null) {
            countSoql += ' AND ActualVisitEndTime >= :dateStart AND ActualVisitEndTime < :dateEnd';
        }

        countSoql += ' GROUP BY Status';

        Map<String, Integer> counts = new Map<String, Integer>();
        for (AggregateResult ar : Database.query(countSoql)) {
            counts.put((String) ar.get('Status'), Integer.valueOf(ar.get('total')));
        }
        return counts;
    }
}