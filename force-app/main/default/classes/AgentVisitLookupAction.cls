public class AgentVisitLookupAction {

    public class LookupRequest {
        @InvocableVariable(description='Name of the site (Context) to look up visits for (e.g., Kothaguda Site A)')
        public String siteName;

        @InvocableVariable(description='Name of the Retail Store to look up visits for (e.g., Kothaguda)')
        public String retailStoreName;

        @InvocableVariable(description='Name of the Retail Store Group / Zone to look up visits for (e.g., Hyderabad North)')
        public String retailStoreGroupName;

        @InvocableVariable(description='Filter by visit status: Planned, InProgress, Completed, or Cancelled. Leave blank for all.')
        public String statusFilter;

        @InvocableVariable(description='Filter completed visits by date: Today, Yesterday, or a date in dd-MM-yyyy format (e.g., 23-04-2026)')
        public String dateFilter;
    }

    public class LookupResult {
        @InvocableVariable(description='Visit response containing the visits list and status counts, consumed by the visitList Lightning Type LWC.')
        public VisitResponseDTO visitResponse;

        @InvocableVariable(description='Plain-text summary for the agent chat response including counts.')
        public String summaryText;
    }

    @InvocableMethod(
        label='Look Up Visits'
        description='Retrieves field visits by site name, retail store, or store group — with optional status and date filters. Also returns attached ContentNotes.'
    )
    public static List<LookupResult> lookup(List<LookupRequest> requests) {
        List<LookupResult> results = new List<LookupResult>();
        IVisitLookup impl = new VisitLookupImpl();

        for (LookupRequest req : requests) {
            List<VisitDTO> visits = impl.lookupVisits(
                req.siteName,
                req.retailStoreName,
                req.retailStoreGroupName,
                req.statusFilter,
                req.dateFilter
            );

            Map<String, Integer> counts = impl.countVisits(
                req.siteName,
                req.retailStoreName,
                req.retailStoreGroupName,
                req.dateFilter
            );

            String context = String.isNotBlank(req.retailStoreGroupName) ? req.retailStoreGroupName
                           : String.isNotBlank(req.retailStoreName)      ? req.retailStoreName
                           : String.isNotBlank(req.siteName)             ? req.siteName
                           : 'the given criteria';

            String statusDesc = String.isNotBlank(req.statusFilter)
                ? req.statusFilter + ' visits'
                : 'visits';

            Integer planned    = counts.containsKey('Planned')    ? counts.get('Planned')    : 0;
            Integer inProgress = counts.containsKey('InProgress') ? counts.get('InProgress') : 0;
            Integer completed  = counts.containsKey('Completed')  ? counts.get('Completed')  : 0;
            Integer cancelled  = counts.containsKey('Cancelled')  ? counts.get('Cancelled')  : 0;

            String countLine = 'Planned: ' + planned +
                               ' | In Progress: ' + inProgress +
                               ' | Completed: ' + completed +
                               ' | Cancelled: ' + cancelled;

            VisitResponseDTO resp  = new VisitResponseDTO();
            resp.visits            = visits;
            resp.plannedCount      = planned;
            resp.inProgressCount   = inProgress;
            resp.completedCount    = completed;
            resp.cancelledCount    = cancelled;

            LookupResult res    = new LookupResult();
            res.visitResponse   = resp;
            res.summaryText     = (visits.isEmpty()
                ? 'No ' + statusDesc + ' found for \'' + context + '\'.'
                : 'Found ' + visits.size() + ' ' + statusDesc
                  + ' for \'' + context + '\''
                  + (String.isNotBlank(req.dateFilter) ? ' on ' + req.dateFilter : '') + '.')
                  + ' ' + countLine;
            results.add(res);
        }
        return results;
    }
}