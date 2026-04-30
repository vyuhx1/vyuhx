public class StoreExpansionSummaryAction {

    public class Request {
        @InvocableVariable(required=true description='Name of the retail store to summarise.')
        public String storeName;
    }

    @InvocableMethod(
        label='Get Store Expansion Summary'
        description='Returns structured store expansion data and a short AI narrative for LWC rendering.'
    )
    public static List<StoreExpansionSummaryDTO> getSummary(List<Request> requests) {
        List<StoreExpansionSummaryDTO> results = new List<StoreExpansionSummaryDTO>();
        for (Request req : requests) {
            results.add(buildDTO(req.storeName));
        }
        return results;
    }

    private static StoreExpansionSummaryDTO buildDTO(String storeName) {
        Boolean hasFilter = String.isNotBlank(storeName);
        String  nameLike  = hasFilter ? '%' + storeName.trim() + '%' : null;

        List<RetailStore> stores = hasFilter
            ? [
                SELECT Id, Name, City__c, SubArea__c,
                       Current_Demand_Score__c, Footfall_Index__c, Demographic_Score__c,
                       EBITDA_Margin__c, Payback_Period_Years__c,
                       RetailLocationGroup.Name,
                       (SELECT Id, Name, Status__c,
                               Competition_Level__c, Competition_Activity__c,
                               Competition_Confidence__c, Competition_Impact__c,
                               Avg_Distance_from_Competitor__c
                        FROM Sites__r ORDER BY Name LIMIT 10)
                FROM RetailStore
                WHERE Name LIKE :nameLike
                ORDER BY Current_Demand_Score__c DESC NULLS LAST
                LIMIT 1
              ]
            : [
                SELECT Id, Name, City__c, SubArea__c,
                       Current_Demand_Score__c, Footfall_Index__c, Demographic_Score__c,
                       EBITDA_Margin__c, Payback_Period_Years__c,
                       RetailLocationGroup.Name,
                       (SELECT Id, Name, Status__c,
                               Competition_Level__c, Competition_Activity__c,
                               Competition_Confidence__c, Competition_Impact__c,
                               Avg_Distance_from_Competitor__c
                        FROM Sites__r ORDER BY Name LIMIT 10)
                FROM RetailStore
                ORDER BY Current_Demand_Score__c DESC NULLS LAST
                LIMIT 1
              ];

        StoreExpansionSummaryDTO dto = new StoreExpansionSummaryDTO();
        dto.sites = new List<StoreExpansionSummaryDTO.SiteSummaryItem>();

        if (stores.isEmpty()) {
            dto.storeName   = storeName;
            dto.aiNarrative = 'No store found matching "' + storeName + '".';
            return dto;
        }

        RetailStore s = stores[0];
        dto.storeName         = s.Name;
        dto.city              = s.City__c;
        dto.subArea           = s.SubArea__c;
        dto.locationGroupName = s.RetailLocationGroup?.Name;
        dto.demandScore       = s.Current_Demand_Score__c;
        dto.footfallIndex     = s.Footfall_Index__c;
        dto.demographicScore  = s.Demographic_Score__c;
        dto.ebitdaMargin      = s.EBITDA_Margin__c;
        dto.paybackPeriod     = s.Payback_Period_Years__c;
        dto.totalSites        = s.Sites__r != null ? s.Sites__r.size() : 0;

        // Build compact context text for LLM + populate site list
        String ctx  = 'Store: ' + s.Name + '\n';
        ctx += 'Location: ' + nvl(s.SubArea__c) + ', ' + nvl(s.City__c) + '\n';
        ctx += 'Demand: ' + fmt(s.Current_Demand_Score__c)
             + ' | Footfall: '   + fmt(s.Footfall_Index__c)   + '%'
             + ' | EBITDA: '     + fmt(s.EBITDA_Margin__c)    + '%'
             + ' | Payback: '    + fmt(s.Payback_Period_Years__c) + ' yrs\n';
        ctx += 'Sites (' + dto.totalSites + '):\n';

        if (s.Sites__r != null) {
            for (Sites__c site : s.Sites__r) {
                StoreExpansionSummaryDTO.SiteSummaryItem item = new StoreExpansionSummaryDTO.SiteSummaryItem();
                item.siteName              = site.Name;
                item.status                = site.Status__c;
                item.competitionLevel      = site.Competition_Level__c     != null ? String.valueOf(site.Competition_Level__c)     : null;
                item.competitionActivity   = site.Competition_Activity__c   != null ? String.valueOf(site.Competition_Activity__c)   : null;
                item.competitionConfidence = site.Competition_Confidence__c != null ? String.valueOf(site.Competition_Confidence__c) : null;
                item.competitionImpact     = site.Competition_Impact__c     != null ? String.valueOf(site.Competition_Impact__c)     : null;
                item.distanceKm            = site.Avg_Distance_from_Competitor__c;
                dto.sites.add(item);

                ctx += '  - ' + nvl(site.Name)
                     + ' | Status: '      + nvl(site.Status__c)
                     + ' | Competition: ' + nvl(site.Competition_Level__c)
                     + ' | Impact: '      + nvl(site.Competition_Impact__c)
                     + ' | Dist: '        + fmt(site.Avg_Distance_from_Competitor__c) + ' km\n';
            }
        }

        // Call simple plain-text prompt template
        try {
            dto.aiNarrative = callNarrativeTemplate(ctx);
        } catch (Exception e) {
            dto.aiNarrative = 'AI summary unavailable: ' + e.getMessage();
        }

        return dto;
    }

    private static String callNarrativeTemplate(String storeContext) {
        ConnectApi.EinsteinPromptTemplateGenerationsInput inp =
            new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        inp.isPreview = false;
        inp.additionalConfig = new ConnectApi.EinsteinLLMAdditionalConfigInput();
        inp.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';

        ConnectApi.WrappedValue wv = new ConnectApi.WrappedValue();
        wv.value = storeContext;
        Map<String, ConnectApi.WrappedValue> params = new Map<String, ConnectApi.WrappedValue>();
        params.put('Input:storeContext', wv);
        inp.inputParams = params;

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                'Store_Expansion_Narrative', inp
            );
        return (result?.generations != null && !result.generations.isEmpty())
            ? result.generations[0].text
            : 'Summary unavailable.';
    }

    private static String fmt(Decimal val) {
        return val != null ? String.valueOf(val.setScale(2)) : 'N/A';
    }

    private static String nvl(Object val) {
        if (val == null) return 'N/A';
        String s = String.valueOf(val).trim();
        return String.isBlank(s) ? 'N/A' : s;
    }
}