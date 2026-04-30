public class RetailStoreDetailsAction {

    public class StoreRequest {
        @InvocableVariable(required=true description='Id or Name of the Retail Store to retrieve')
        public String storeIdOrName;
    }

    public class StoreResult {
        @InvocableVariable(description='List of RetailStoreListDTO objects, consumed by the retailStoreList Lightning Type LWC.')
        public List<RetailStoreListDTO> retailStores;

        @InvocableVariable(description='Plain-text summary for the agent chat response.')
        public String summaryText;
    }

    @InvocableMethod(label='Get Retail Store Details' description='Returns key details of a Retail Store given its Id or Name. Falls back to all stores if no match is found.')
    public static List<StoreResult> getStoreDetails(List<StoreRequest> requests) {
        List<StoreResult> results = new List<StoreResult>();

        for (StoreRequest req : requests) {
            Boolean hasInput = String.isNotBlank(req.storeIdOrName);
            String searchVal = hasInput ? req.storeIdOrName.trim() : null;

            List<RetailStore> stores = hasInput
                ? [
                    SELECT Id, Name, City__c, SubArea__c,
                           Footfall_Index__c, Current_Demand_Score__c, Demographic_Score__c,
                           EBITDA_Margin__c, Payback_Period_Years__c,
                           RetailLocationGroupId, RetailLocationGroup.Name, RetailLocationGroup.Area__c, RetailLocationGroup.pincode__c,
                           (SELECT Id, Name, Status__c,
                                   Competition_Level__c, Competition_Activity__c,
                                   Competition_Confidence__c, Competition_Impact__c,
                                   Avg_Distance_from_Competitor__c,
                                   Proposed_Site_Location__latitude__s,
                                   Proposed_Site_Location__longitude__s
                            FROM Sites__r
                            ORDER BY Name)
                    FROM RetailStore
                    WHERE Id = :searchVal OR Name = :searchVal
                    LIMIT 1
                  ]
                : new List<RetailStore>();

            StoreResult res = new StoreResult();

            // No match (or blank input) — fall back to all stores
            if (stores.isEmpty()) {
                stores = [
                    SELECT Id, Name, City__c, SubArea__c,
                           Footfall_Index__c, Current_Demand_Score__c, Demographic_Score__c,
                           EBITDA_Margin__c, Payback_Period_Years__c, RetailLocationGroupId,
                           RetailLocationGroup.Name, RetailLocationGroup.Area__c, RetailLocationGroup.pincode__c,
                           (SELECT Id, Name, Status__c,
                                   Competition_Level__c, Competition_Activity__c,
                                   Competition_Confidence__c, Competition_Impact__c,
                                   Avg_Distance_from_Competitor__c,
                                   Proposed_Site_Location__latitude__s,
                                   Proposed_Site_Location__longitude__s
                            FROM Sites__r
                            ORDER BY Name)
                    FROM RetailStore
                    ORDER BY Name
                    LIMIT 200
                ];
                res.summaryText = hasInput
                    ? 'No store found for \'' + searchVal + '\'. Showing all ' + stores.size() + ' retail store(s).'
                    : 'Showing all ' + stores.size() + ' retail store(s).';
            } else {
                res.summaryText = 'Found retail store: ' + stores[0].Name + '.';
            }

            // Collect site Ids and query Visits
            Set<Id> siteIds = new Set<Id>();
            for (RetailStore s : stores) {
                for (Sites__c site : s.Sites__r) {
                    siteIds.add(site.Id);
                }
            }

            Map<Id, List<SiteVisitDTO>> visitsBySiteId = new Map<Id, List<SiteVisitDTO>>();
            if (!siteIds.isEmpty()) {
                for (Visit v : [
                    SELECT Id, Name, Status, VisitPriority, ContextId
                    FROM Visit
                    WHERE ContextId IN :siteIds
                    ORDER BY Name
                    LIMIT 1000
                ]) {
                    if (!visitsBySiteId.containsKey(v.ContextId)) {
                        visitsBySiteId.put(v.ContextId, new List<SiteVisitDTO>());
                    }
                    SiteVisitDTO vDto = new SiteVisitDTO();
                    vDto.visitId  = v.Id;
                    vDto.visitName = v.Name;
                    vDto.status   = v.Status;
                    vDto.priority = v.VisitPriority;
                    visitsBySiteId.get(v.ContextId).add(vDto);
                }
            }

            List<RetailStoreListDTO> dtoList = new List<RetailStoreListDTO>();
            for (RetailStore s : stores) {
                dtoList.add(toDTO(s, visitsBySiteId));
            }
            res.retailStores = dtoList;
            results.add(res);
        }

        return results;
    }

    private static RetailStoreListDTO toDTO(RetailStore s, Map<Id, List<SiteVisitDTO>> visitsBySiteId) {
        RetailStoreListDTO dto = new RetailStoreListDTO();
        dto.storeId            = s.Id;
        dto.storeName          = s.Name;
        dto.city               = s.City__c;
        dto.subArea            = s.SubArea__c;
        dto.footfallIndex      = s.Footfall_Index__c;
        dto.currentDemandScore = s.Current_Demand_Score__c;
        dto.demographicScore   = s.Demographic_Score__c;
        dto.ebitdaMargin       = s.EBITDA_Margin__c;
        dto.paybackPeriodYears = s.Payback_Period_Years__c;
        if (s.RetailLocationGroupId != null) {
            dto.retailLocationGroupId      = s.RetailLocationGroupId;
            dto.retailLocationGroupName    = s.RetailLocationGroup?.Name;
            dto.retailLocationGroupArea    = s.RetailLocationGroup?.Area__c;
            dto.retailLocationGroupPincode = s.RetailLocationGroup?.pincode__c;
        }

        // Build nested sites
        List<SiteListDTO> siteDtos = new List<SiteListDTO>();
        for (Sites__c site : s.Sites__r) {
            SiteListDTO sDto = new SiteListDTO();
            sDto.siteId                = site.Id;
            sDto.siteName              = site.Name;
            sDto.status                = site.Status__c;
            sDto.competitionLevel      = site.Competition_Level__c;
            sDto.competitionActivity   = site.Competition_Activity__c;
            sDto.competitionConfidence = site.Competition_Confidence__c;
            sDto.competitionImpact     = site.Competition_Impact__c;
            sDto.distanceKm            = site.Avg_Distance_from_Competitor__c;
            sDto.latitude              = site.Proposed_Site_Location__latitude__s;
            sDto.longitude             = site.Proposed_Site_Location__longitude__s;
            sDto.retailStoreId         = s.Id;
            sDto.retailStoreName       = s.Name;
            sDto.retailStoreCity       = s.City__c;
            sDto.retailStoreSubArea    = s.SubArea__c;
            sDto.visits                = visitsBySiteId.containsKey(site.Id)
                ? visitsBySiteId.get(site.Id)
                : new List<SiteVisitDTO>();
            siteDtos.add(sDto);
        }
        dto.sites = siteDtos;

        return dto;
    }
}