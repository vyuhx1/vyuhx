public class SiteEvaluatorImpl implements ISiteEvaluator {
    public List<SiteEvaluationDTO> evaluateSite(String storeName) {
        String searchKey = '%' + storeName + '%';

        List<RetailStore> sites = [
            SELECT Id, Name, City__c, SubArea__c,
                   Current_Demand_Score__c, Footfall_Index__c, Demographic_Score__c,
                   Expected_Annual_Revenue__c, EBITDA_Margin__c, Payback_Period_Years__c,
                   Competition_Level__c,
                   RetailLocationGroup.Name,
                   (SELECT Id,Name,
                           Avg_Distance_from_Competitor__c,
                           Competition_Level__c,
                           Competition_Activity__c,
                           Competition_Confidence__c,
                           Competition_Impact__c,
                           Proposed_Site_Location__latitude__s,
                           Proposed_Site_Location__longitude__s
                    FROM Sites__r
                    ORDER BY Competition_Confidence__c DESC
                    LIMIT 3)
            FROM RetailStore
            WHERE Name LIKE :searchKey
            ORDER BY Current_Demand_Score__c DESC
        ];

        List<SiteEvaluationDTO> results = new List<SiteEvaluationDTO>();

        for (RetailStore site : sites) {
            List<SiteDetailDTO> proposedSites = new List<SiteDetailDTO>();

            if (site.Sites__r != null) {
                for (Sites__c s : site.Sites__r) {
                    SiteDetailDTO sd = new SiteDetailDTO();
                    sd.siteId              = s.Id;
                    sd.siteLabel           = s.Name;
                    sd.distanceKm          = s.Avg_Distance_from_Competitor__c;
                    sd.competitionLevel    = s.Competition_Level__c;
                    sd.competitionActivity = s.Competition_Activity__c;
                    sd.competitionConfidence = s.Competition_Confidence__c;
                    sd.competitionImpact   = s.Competition_Impact__c;
                    sd.latitude            = s.Proposed_Site_Location__latitude__s;
                    sd.longitude           = s.Proposed_Site_Location__longitude__s;
                    proposedSites.add(sd);
                }
            }

            SiteEvaluationDTO dto = new SiteEvaluationDTO();
            dto.siteId           = site.Id;
            dto.siteName         = site.Name;
            dto.zone             = site.RetailLocationGroup != null ? site.RetailLocationGroup.Name : 'N/A';
            dto.city             = site.City__c;
            dto.subArea          = site.SubArea__c;
            dto.demandScore      = site.Current_Demand_Score__c;
            dto.footfallIndex    = site.Footfall_Index__c;
            dto.demographicScore = site.Demographic_Score__c;
            dto.estimatedAnnualRevenue = site.Expected_Annual_Revenue__c;
            dto.ebitdaMargin     = site.EBITDA_Margin__c;
            dto.paybackPeriod    = site.Payback_Period_Years__c != null
                                   ? site.Payback_Period_Years__c.setScale(1)
                                   : null;
            dto.competitionLevel = site.Competition_Level__c;
            dto.proposedSites  = proposedSites;

            results.add(dto);
        }

        return results;
    }
}