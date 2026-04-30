public class AgentSiteEvaluatorAction {
    public class EvaluationRequest {
        @InvocableVariable(required=true description='Name of the proposed site (e.g., Kothaguda)')
        public String storeName;
    }

    public class EvaluationResult {
        @InvocableVariable(description='List of SiteEvaluationDTO objects, consumed by the siteEvaluationList Lightning Type LWC.')
        public List<SiteEvaluationDTO> siteEvaluations;

        @InvocableVariable(description='Plain-text summary for the agent chat response.')
        public String summaryText;
    }

    @InvocableMethod(label='Evaluate Proposed Retail Site' description='Generates ROI and competition analysis for all matching proposed sites.')
    public static List<EvaluationResult> evaluate(List<EvaluationRequest> requests) {
        List<EvaluationResult> results = new List<EvaluationResult>();
        ISiteEvaluator evaluator = new SiteEvaluatorImpl();

        for (EvaluationRequest req : requests) {
            List<SiteEvaluationDTO> dtoList = evaluator.evaluateSite(req.storeName);
            EvaluationResult res = new EvaluationResult();
            res.siteEvaluations = dtoList;
            res.summaryText = dtoList.isEmpty()
                ? 'No proposed sites found matching \'' + req.storeName + '\'.'
                : 'Found ' + dtoList.size() + ' proposed site' + (dtoList.size() > 1 ? 's' : '') + ' matching \'' + req.storeName + '\'.';
            results.add(res);
        }
        return results;
    }
}