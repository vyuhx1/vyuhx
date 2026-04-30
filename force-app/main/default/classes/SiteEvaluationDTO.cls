public class SiteEvaluationDTO {
    public String  siteId;
    public String  siteName;
    public String  zone;
    public String  city;
    public String  subArea;
    // Demand signals (from DemandScoreFinal__cio)
    public Decimal demandScore;
    public Decimal footfallIndex;
    public Decimal demographicScore;
    public Decimal estimatedAnnualRevenue;
    // Financial signals (from POS_Metrics__cio)
    public Decimal ebitdaMargin;
    public Decimal paybackPeriod;
    // Competition level from RetailStore (High / Medium / Low picklist)
    public String  competitionLevel;
    // Up to 3 Sites__c records — each represents one competitor data point
    public List<SiteDetailDTO> proposedSites;
}