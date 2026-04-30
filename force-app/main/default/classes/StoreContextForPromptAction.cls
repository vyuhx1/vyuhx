public class StoreContextForPromptAction {

    public class Request {
        @InvocableVariable(
            required=true
            description='Name of the retail store. Supports partial/fuzzy match (e.g. "Kondapur"). Pass blank to get top 5 stores by demand.'
        )
        public String storeName;
    }

    public class Result {
        @InvocableVariable(
            description='Structured plain-text block describing the store, its sites and field visits. Pass this directly into your prompt template as the storeContext merge field.'
        )
        public String storeContext;
    }

    @InvocableMethod(
        label='Get Store Context For Prompt'
        description='Queries a retail store by name along with its sites and field visits, and returns a structured plain-text block ready to inject into an Einstein Prompt Template.'
    )
    public static List<Result> getContext(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result r = new Result();
            try {
                r.storeContext = buildContext(req.storeName);
            } catch (Exception e) {
                r.storeContext = 'Error building store context: ' + e.getMessage();
            }
            results.add(r);
        }
        return results;
    }

    // ─── Build the plain-text context block ──────────────────────────────────

    private static String buildContext(String storeName) {

        Boolean hasFilter = String.isNotBlank(storeName);
        String  nameLike  = hasFilter ? '%' + storeName.trim() + '%' : null;

        // 1. Query store(s) with nested sites
        List<RetailStore> stores = hasFilter
            ? [
                SELECT Id, Name, City__c, SubArea__c,
                       Current_Demand_Score__c, Footfall_Index__c, Demographic_Score__c,
                       EBITDA_Margin__c, Payback_Period_Years__c,
                       RetailLocationGroupId,
                       RetailLocationGroup.Name,
                       RetailLocationGroup.Area__c,
                       RetailLocationGroup.pincode__c,
                       (SELECT Id, Name, Status__c,
                               Competition_Level__c, Competition_Activity__c,
                               Competition_Confidence__c, Competition_Impact__c,
                               Avg_Distance_from_Competitor__c
                        FROM Sites__r
                        ORDER BY Competition_Confidence__c DESC
                        LIMIT 3)
                FROM RetailStore
                WHERE Name LIKE :nameLike
                ORDER BY Current_Demand_Score__c DESC NULLS LAST
                LIMIT 3
              ]
            : [
                SELECT Id, Name, City__c, SubArea__c,
                       Current_Demand_Score__c, Footfall_Index__c, Demographic_Score__c,
                       EBITDA_Margin__c, Payback_Period_Years__c,
                       RetailLocationGroupId,
                       RetailLocationGroup.Name,
                       RetailLocationGroup.Area__c,
                       RetailLocationGroup.pincode__c,
                       (SELECT Id, Name, Status__c,
                               Competition_Level__c, Competition_Activity__c,
                               Competition_Confidence__c, Competition_Impact__c,
                               Avg_Distance_from_Competitor__c
                        FROM Sites__r
                        ORDER BY Competition_Confidence__c DESC
                        LIMIT 3)
                FROM RetailStore
                ORDER BY Current_Demand_Score__c DESC NULLS LAST
                LIMIT 5
              ];

        if (stores.isEmpty()) {
            return 'No retail stores found' + (hasFilter ? ' matching "' + storeName + '".' : '.');
        }

        // 2. Collect all site IDs
        Set<Id> siteIds = new Set<Id>();
        for (RetailStore s : stores) {
            for (Sites__c site : s.Sites__r) {
                siteIds.add(site.Id);
            }
        }

        // 3. Batch-query visits (capped to avoid heap limits)
        Map<Id, List<Visit>> visitsBySite = new Map<Id, List<Visit>>();
        Set<Id> allVisitIds = new Set<Id>();
        if (!siteIds.isEmpty()) {
            for (Visit v : [
                SELECT Id, Name, Status, VisitPriority,
                       StatusRemarks, InstructionDescription, ContextId
                FROM Visit
                WHERE ContextId IN :siteIds
                  AND Status = 'Completed'
                ORDER BY LastModifiedDate DESC
                LIMIT 500
            ]) {
                if (!visitsBySite.containsKey(v.ContextId)) {
                    visitsBySite.put(v.ContextId, new List<Visit>());
                }
                List<Visit> vl = visitsBySite.get(v.ContextId);
                if (vl.size() < 3) {   // cap 3 visits per site
                    vl.add(v);
                }
                allVisitIds.add(v.Id);
            }
        }

        // 4. Batch-query ContentNotes for all visits (same pattern as VisitLookupImpl)
        Map<Id, Id>          docToVisitId  = new Map<Id, Id>();
        Set<Id>              allDocIds     = new Set<Id>();
        Map<Id, List<String>> notesByVisit = new Map<Id, List<String>>();
        if (!allVisitIds.isEmpty()) {
            for (ContentDocumentLink cdl : [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :allVisitIds
            ]) {
                docToVisitId.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
                allDocIds.add(cdl.ContentDocumentId);
            }
        }
        if (!allDocIds.isEmpty()) {
            for (ContentNote cn : [
                SELECT Id, Title, TextPreview, LastModifiedDate
                FROM ContentNote
                WHERE Id IN :allDocIds
                ORDER BY LastModifiedDate DESC
            ]) {
                Id vid = docToVisitId.get(cn.Id);
                if (vid == null) continue;
                if (!notesByVisit.containsKey(vid)) {
                    notesByVisit.put(vid, new List<String>());
                }
                List<String> nl = notesByVisit.get(vid);
                if (nl.size() < 3) {   // cap 3 notes per visit
                    String preview = String.isNotBlank(cn.TextPreview)
                        ? cn.TextPreview.abbreviate(200) : '(no preview)';
                    nl.add('[' + cn.Title + ']: ' + preview);
                }
            }
        }

        // 5. Build text block
        String NL = '\n';
        String out = '=== RETAIL STORE EXPANSION CONTEXT ===' + NL + NL;

        for (RetailStore s : stores) {
            out += 'STORE: ' + s.Name + NL;
            out += '  Location   : ' + nvl(s.SubArea__c) + ', ' + nvl(s.City__c) + NL;
            if (s.RetailLocationGroupId != null) {
                out += '  Group      : ' + nvl(s.RetailLocationGroup?.Name)
                     + '  Area: '        + nvl(s.RetailLocationGroup?.Area__c)
                     + '  Pincode: '     + nvl(s.RetailLocationGroup?.pincode__c) + NL;
            }
            out += '  Demand Score     : ' + fmt(s.Current_Demand_Score__c) + NL;
            out += '  Footfall Index   : ' + fmt(s.Footfall_Index__c)       + '%' + NL;
            out += '  Demographic Score: ' + fmt(s.Demographic_Score__c)    + '%' + NL;
            out += '  EBITDA Margin    : ' + fmt(s.EBITDA_Margin__c)        + '%' + NL;
            out += '  Payback Period   : ' + fmt(s.Payback_Period_Years__c) + ' yrs' + NL;

            List<Sites__c> sites = s.Sites__r;
            Integer sCount = (sites == null) ? 0 : sites.size();
            out += '  SITES (' + sCount + '):' + NL;

            if (sCount == 0) {
                out += '    (none)' + NL;
            } else {
                Integer sn = 0;
                for (Sites__c site : sites) {
                    sn++;
                    out += '    [' + sn + '] ' + nvl(site.Name) + NL;
                    out += '        Status            : ' + nvl(site.Status__c)                        + NL;
                    out += '        Competition Level : ' + nvl(site.Competition_Level__c)             + NL;
                    out += '        Competition Act.  : ' + nvl(site.Competition_Activity__c)          + NL;
                    out += '        Confidence        : ' + nvl(site.Competition_Confidence__c)        + NL;
                    out += '        Impact            : ' + nvl(site.Competition_Impact__c)            + NL;
                    out += '        Avg Dist (km)     : ' + fmt(site.Avg_Distance_from_Competitor__c)  + NL;

                    List<Visit> visits = visitsBySite.containsKey(site.Id)
                        ? visitsBySite.get(site.Id) : new List<Visit>();

                    out += '        VISITS (' + visits.size() + '):' + NL;
                    if (visits.isEmpty()) {
                        out += '          (no completed visits — pending)' + NL;
                    } else {
                        for (Visit v : visits) {
                            out += '          - ' + nvl(v.Name)
                                 + '  |  Status: '   + nvl(v.Status)
                                 + '  |  Priority: ' + nvl(v.VisitPriority) + NL;
                            if (String.isNotBlank(v.StatusRemarks)) {
                                out += '            Remarks     : ' + v.StatusRemarks.abbreviate(250) + NL;
                            }
                            if (String.isNotBlank(v.InstructionDescription)) {
                                out += '            Instructions: ' + v.InstructionDescription.abbreviate(250) + NL;
                            }
                            List<String> notes = notesByVisit.containsKey(v.Id)
                                ? notesByVisit.get(v.Id) : new List<String>();
                            if (!notes.isEmpty()) {
                                out += '            Notes:' + NL;
                                for (String note : notes) {
                                    out += '              * ' + note + NL;
                                }
                            }
                        }
                    }
                }
            }
            out += NL;
        }

        return out;
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private static String fmt(Decimal val) {
        return val != null ? String.valueOf(val.setScale(2)) : 'N/A';
    }

    private static String nvl(Object val) {
        if (val == null) return 'N/A';
        String s = String.valueOf(val).trim();
        return String.isBlank(s) ? 'N/A' : s;
    }
}