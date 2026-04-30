public class StoreExpansionSummaryDTO {
    @AuraEnabled @InvocableVariable public String  storeName;
    @AuraEnabled @InvocableVariable public String  city;
    @AuraEnabled @InvocableVariable public String  subArea;
    @AuraEnabled @InvocableVariable public String  locationGroupName;
    @AuraEnabled @InvocableVariable public Decimal demandScore;
    @AuraEnabled @InvocableVariable public Decimal footfallIndex;
    @AuraEnabled @InvocableVariable public Decimal demographicScore;
    @AuraEnabled @InvocableVariable public Decimal ebitdaMargin;
    @AuraEnabled @InvocableVariable public Decimal paybackPeriod;
    @AuraEnabled @InvocableVariable public Integer totalSites;
    @AuraEnabled @InvocableVariable public String  aiNarrative;
    @AuraEnabled public List<SiteSummaryItem> sites;

    public class SiteSummaryItem {
        @AuraEnabled public String  siteName;
        @AuraEnabled public String  status;
        @AuraEnabled public String  competitionLevel;
        @AuraEnabled public String  competitionActivity;
        @AuraEnabled public String  competitionConfidence;
        @AuraEnabled public String  competitionImpact;
        @AuraEnabled public Decimal distanceKm;
    }
}