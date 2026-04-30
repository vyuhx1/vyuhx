public class AgentStoreSummaryAction {

    public class SummaryRequest {
        @InvocableVariable(
            required=true
            description='Id of the RetailStore record to summarise.'
        )
        public String storeId;
    }

    public class SummaryResult {
        @InvocableVariable(
            description='StoreSummaryDTO consumed by the storeSummaryCard Lightning Type LWC.'
        )
        public StoreSummaryDTO storeSummary;

        @InvocableVariable(
            description='Plain-text acknowledgement for the agent chat response.'
        )
        public String summaryText;
    }

    @InvocableMethod(
        label='Generate Store Expansion Summary'
        description='Calls the Store_Agent_Summary prompt template for a RetailStore and returns a StoreSummaryDTO for rendering in the storeSummaryCard LWC.'
    )
    public static List<SummaryResult> generate(List<SummaryRequest> requests) {
        List<SummaryResult> results = new List<SummaryResult>();
        for (SummaryRequest req : requests) {
            SummaryResult res = new SummaryResult();
            try {
                StoreSummaryController.SummaryResult raw =
                    StoreSummaryController.generateSummary(req.storeId);

                StoreSummaryDTO dto = new StoreSummaryDTO();
                dto.storeName = raw.storeName;
                dto.summary   = raw.summary;

                res.storeSummary = dto;
                res.summaryText  = 'Expansion summary generated for ' + raw.storeName + '.';
            } catch (Exception e) {
                res.summaryText = 'Could not generate summary: ' + e.getMessage();
            }
            results.add(res);
        }
        return results;
    }
}