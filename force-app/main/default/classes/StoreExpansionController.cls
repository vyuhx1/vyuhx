public with sharing class StoreExpansionController {
    @AuraEnabled(cacheable=true)
    public static List<RetailStore> getProposedSites() {
        // Fetch threshold from CMDT
        Expansion_Dashboard_Setting__mdt settings = Expansion_Dashboard_Setting__mdt.getInstance('Default_Settings');
        Decimal minDemand = settings != null && settings.Minimum_Demand_Score__c != null ? settings.Minimum_Demand_Score__c : 0;
        return [
            SELECT Id, Name, Current_Demand_Score__c, Competition_Level__c, 
                   Estimated_Rent__c, Payback_Period_Years__c, Expected_Annual_Revenue__c,
                   Site_Location__latitude__s, Site_Location__longitude__s,
                   RetailLocationGroup.Name
            FROM RetailStore
            WHERE Current_Demand_Score__c >= :minDemand
            WITH SECURITY_ENFORCED
            ORDER BY Current_Demand_Score__c DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Sites__c> getSitesForStore(Id storeId) {
        return [
            SELECT Id,
                   Proposed_Site_Location__latitude__s,
                   Proposed_Site_Location__longitude__s,
                   Competition_Level__c,
                   Competition_Activity__c,
                   Competition_Confidence__c,
                   Competition_Impact__c
            FROM Sites__c
            WHERE Retail_Store__c = :storeId
            ORDER BY Competition_Confidence__c DESC NULLS LAST
            LIMIT 3
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Sites__c> getSitesForDashboard() {
        Expansion_Dashboard_Setting__mdt settings = Expansion_Dashboard_Setting__mdt.getInstance('Default_Settings');
        Decimal minDemand = settings != null && settings.Minimum_Demand_Score__c != null ? settings.Minimum_Demand_Score__c : 0;
        Set<Id> storeIds = new Map<Id, RetailStore>([
            SELECT Id FROM RetailStore
            WHERE Current_Demand_Score__c >= :minDemand
            WITH SECURITY_ENFORCED
        ]).keySet();
        return [
            SELECT Id, Name, Retail_Store__c,
                   Proposed_Site_Location__latitude__s,
                   Proposed_Site_Location__longitude__s,
                   Competition_Level__c,
                   Competition_Activity__c,
                   Competition_Confidence__c,
                   Competition_Impact__c
            FROM Sites__c
            WHERE Retail_Store__c IN :storeIds
            ORDER BY Retail_Store__c, Competition_Confidence__c DESC NULLS LAST
        ];
    }
    @AuraEnabled(cacheable=false)
    public static List<Visit> getRecentFieldVisits(String groupName, String storeName, Integer pageOffset) {
        Integer off = pageOffset != null ? pageOffset : 0;
        Set<Id> siteIds;

        if (String.isNotBlank(storeName)) {
            // Filter by retail store name (takes priority over group)
            String storeKey = '%' + storeName + '%';
            List<Sites__c> sites = [
                SELECT Id FROM Sites__c
                WHERE Retail_Store__r.Name LIKE :storeKey
            ];
            if (sites.isEmpty()) return new List<Visit>();
            siteIds = new Map<Id, Sites__c>(sites).keySet();
        } else if (String.isNotBlank(groupName)) {
            List<Sites__c> sites = [
                SELECT Id FROM Sites__c
                WHERE Retail_Store__r.RetailLocationGroup.Name = :groupName
            ];
            if (sites.isEmpty()) return new List<Visit>();
            siteIds = new Map<Id, Sites__c>(sites).keySet();
        }

        if (siteIds != null) {
            return [
                SELECT Id, Context.Name, ContextId, PlannedVisitStartTime, Status,
                       VisitorId, Visitor.Name
                FROM Visit
                WHERE ContextId IN :siteIds
                ORDER BY PlannedVisitStartTime DESC
                LIMIT 6 OFFSET :off
            ];
        }
        return [
            SELECT Id, Context.Name, ContextId, PlannedVisitStartTime, Status,
                   VisitorId, Visitor.Name
            FROM Visit
            WHERE ContextId != null
            ORDER BY PlannedVisitStartTime DESC
            LIMIT 6 OFFSET :off
        ];
    }

    @AuraEnabled
    public static String sendVisitNotifications() {
        try {
            VisitNotificationService.sendVisitAlerts();
            return 'success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String sendSingleVisitNotification(Id visitId) {
        try {
            VisitNotificationService.sendAlertForVisit(visitId);
            return 'success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static StoreEvalResult getStoreEvaluation(Id storeId) {
        RetailStore rs = [
            SELECT Id, Name, Current_Demand_Score__c, Competition_Level__c,
                   Expected_Annual_Revenue__c, Payback_Period_Years__c,
                   Footfall_Index__c, Demographic_Score__c, EBITDA_Margin__c,
                   RetailLocationGroup.Name
            FROM RetailStore
            WHERE Id = :storeId
            WITH SECURITY_ENFORCED
        ];

        List<Sites__c> sites = [
            SELECT Id, Name, Competition_Level__c, Competition_Activity__c,
                   Competition_Confidence__c, Competition_Impact__c
            FROM Sites__c
            WHERE Retail_Store__c = :storeId
            ORDER BY Competition_Confidence__c DESC NULLS LAST
            LIMIT 3
        ];

        StoreEvalResult result = new StoreEvalResult();
        result.siteId                 = rs.Id;
        result.siteName               = rs.Name;
        result.zone                   = rs.RetailLocationGroup != null ? rs.RetailLocationGroup.Name : 'N/A';
        result.demandScore            = rs.Current_Demand_Score__c;
        result.competitionLevel       = rs.Competition_Level__c;
        result.estimatedAnnualRevenue = rs.Expected_Annual_Revenue__c;
        result.paybackPeriod          = rs.Payback_Period_Years__c;
        result.footfallIndex          = rs.Footfall_Index__c;
        result.demographicScore       = rs.Demographic_Score__c;
        result.ebitdaMargin           = rs.EBITDA_Margin__c;

        List<ProposedSiteRow> siteRows = new List<ProposedSiteRow>();
        for (Sites__c s : sites) {
            ProposedSiteRow r = new ProposedSiteRow();
            r.siteId                 = s.Id;
            r.siteName               = s.Name;
            r.competitionLevel       = s.Competition_Level__c;
            r.competitionActivity    = s.Competition_Activity__c;
            r.competitionConfidence  = s.Competition_Confidence__c;
            r.competitionImpact      = s.Competition_Impact__c;
            siteRows.add(r);
        }
        result.proposedSites = siteRows;
        return result;
    }

    public class StoreEvalResult {
        @AuraEnabled public String  siteId;
        @AuraEnabled public String  siteName;
        @AuraEnabled public String  zone;
        @AuraEnabled public Decimal demandScore;
        @AuraEnabled public String  competitionLevel;
        @AuraEnabled public Decimal estimatedAnnualRevenue;
        @AuraEnabled public Decimal paybackPeriod;
        @AuraEnabled public Decimal footfallIndex;
        @AuraEnabled public Decimal demographicScore;
        @AuraEnabled public Decimal ebitdaMargin;
        @AuraEnabled public List<ProposedSiteRow> proposedSites;
    }

    public class ProposedSiteRow {
        @AuraEnabled public String  siteId;
        @AuraEnabled public String  siteName;
        @AuraEnabled public Decimal competitionLevel;
        @AuraEnabled public Decimal competitionActivity;
        @AuraEnabled public Decimal competitionConfidence;
        @AuraEnabled public Decimal competitionImpact;
    }
}