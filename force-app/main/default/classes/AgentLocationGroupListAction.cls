public class AgentLocationGroupListAction {

    public class GroupRequest {
        @InvocableVariable(description='Optional Retail Location Group name filter. Leave blank to retrieve all groups.')
        public String groupName;
    }

    public class GroupListResult {
        @InvocableVariable(description='List of RetailLocationGroupDTO objects, consumed by the locationGroupList Lightning Type LWC.')
        public List<RetailLocationGroupDTO> locationGroups;

        @InvocableVariable(description='Plain-text summary for the agent chat response.')
        public String summaryText;
    }

    @InvocableMethod(label='Get Location Group List' description='Retrieves Retail Location Groups with their Retail Stores, Sites and Visits hierarchy. Optionally filter by group name — leave blank to get all.')
    public static List<GroupListResult> getLocationGroups(List<GroupRequest> requests) {
        List<GroupListResult> results = new List<GroupListResult>();

        for (GroupRequest req : requests) {
            Boolean hasFilter = String.isNotBlank(req.groupName);
            String nameFilter = hasFilter ? '%' + req.groupName.trim() + '%' : null;

            // Step 1 — Query groups
            List<RetailLocationGroup> groups = hasFilter
                ? [
                    SELECT Id, Name, Area__c, pincode__c
                    FROM RetailLocationGroup
                    WHERE Name LIKE :nameFilter
                    ORDER BY Name
                    LIMIT 100
                  ]
                : [
                    SELECT Id, Name, Area__c, pincode__c
                    FROM RetailLocationGroup
                    ORDER BY Name
                    LIMIT 100
                  ];

            // Fall back to all groups if filter matched nothing
            if (groups.isEmpty() && hasFilter) {
                groups = [
                    SELECT Id, Name, Area__c, pincode__c
                    FROM RetailLocationGroup
                    ORDER BY Name
                    LIMIT 100
                ];
            }

            // Step 2 — Query RetailStores (with Sites sub-query) for those groups
            Set<Id> groupIds = new Set<Id>();
            for (RetailLocationGroup g : groups) {
                groupIds.add(g.Id);
            }

            List<RetailStore> stores = [
                SELECT Id, Name, City__c, SubArea__c,
                       Footfall_Index__c, Current_Demand_Score__c, Demographic_Score__c,
                       EBITDA_Margin__c, Payback_Period_Years__c,
                       RetailLocationGroupId,
                       (SELECT Id, Name, Status__c,
                               Competition_Level__c, Competition_Activity__c,
                               Competition_Confidence__c, Competition_Impact__c,
                               Avg_Distance_from_Competitor__c,
                               Proposed_Site_Location__latitude__s,
                               Proposed_Site_Location__longitude__s
                        FROM Sites__r
                        ORDER BY Name)
                FROM RetailStore
                WHERE RetailLocationGroupId IN :groupIds
                ORDER BY Name
            ];

            // Step 3 — Collect all site Ids, query Visits by ContextId
            Set<Id> siteIds = new Set<Id>();
            for (RetailStore store : stores) {
                for (Sites__c site : store.Sites__r) {
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
                    vDto.visitId   = v.Id;
                    vDto.visitName = v.Name;
                    vDto.status    = v.Status;
                    vDto.priority  = v.VisitPriority;
                    visitsBySiteId.get(v.ContextId).add(vDto);
                }
            }

            // Step 4 — Build RetailStoreListDTO (with nested SiteListDTOs) grouped by RetailLocationGroupId
            Map<Id, List<RetailStoreListDTO>> storesByGroupId = new Map<Id, List<RetailStoreListDTO>>();
            for (RetailStore s : stores) {
                // Build sites
                List<SiteListDTO> siteDtos = new List<SiteListDTO>();
                for (Sites__c site : s.Sites__r) {
                    SiteListDTO sDto = new SiteListDTO();
                    sDto.siteId               = site.Id;
                    sDto.siteName             = site.Name;
                    sDto.status               = site.Status__c;
                    sDto.competitionLevel     = site.Competition_Level__c;
                    sDto.competitionActivity  = site.Competition_Activity__c;
                    sDto.competitionConfidence = site.Competition_Confidence__c;
                    sDto.competitionImpact    = site.Competition_Impact__c;
                    sDto.distanceKm           = site.Avg_Distance_from_Competitor__c;
                    sDto.latitude             = site.Proposed_Site_Location__latitude__s;
                    sDto.longitude            = site.Proposed_Site_Location__longitude__s;
                    sDto.retailStoreId        = s.Id;
                    sDto.retailStoreName      = s.Name;
                    sDto.retailStoreCity      = s.City__c;
                    sDto.retailStoreSubArea   = s.SubArea__c;
                    sDto.visits               = visitsBySiteId.containsKey(site.Id)
                        ? visitsBySiteId.get(site.Id)
                        : new List<SiteVisitDTO>();
                    siteDtos.add(sDto);
                }

                // Build store DTO
                RetailStoreListDTO storeDto = new RetailStoreListDTO();
                storeDto.storeId            = s.Id;
                storeDto.storeName          = s.Name;
                storeDto.city               = s.City__c;
                storeDto.subArea            = s.SubArea__c;
                storeDto.footfallIndex      = s.Footfall_Index__c;
                storeDto.currentDemandScore = s.Current_Demand_Score__c;
                storeDto.demographicScore   = s.Demographic_Score__c;
                storeDto.ebitdaMargin       = s.EBITDA_Margin__c;
                storeDto.paybackPeriodYears = s.Payback_Period_Years__c;
                storeDto.retailLocationGroupId = s.RetailLocationGroupId;
                storeDto.sites              = siteDtos;

                if (!storesByGroupId.containsKey(s.RetailLocationGroupId)) {
                    storesByGroupId.put(s.RetailLocationGroupId, new List<RetailStoreListDTO>());
                }
                storesByGroupId.get(s.RetailLocationGroupId).add(storeDto);
            }

            // Step 5 — Build RetailLocationGroupDTOs
            List<RetailLocationGroupDTO> dtoList = new List<RetailLocationGroupDTO>();
            for (RetailLocationGroup g : groups) {
                RetailLocationGroupDTO dto = new RetailLocationGroupDTO();
                dto.groupId   = g.Id;
                dto.groupName = g.Name;
                dto.area      = g.Area__c;
                dto.pincode   = g.pincode__c;
                dto.stores    = storesByGroupId.containsKey(g.Id)
                    ? storesByGroupId.get(g.Id)
                    : new List<RetailStoreListDTO>();
                dto.storeCount = dto.stores.size();

                Integer sCount = 0, vCount = 0;
                for (RetailStoreListDTO storeDto : dto.stores) {
                    sCount += storeDto.sites != null ? storeDto.sites.size() : 0;
                    if (storeDto.sites != null) {
                        for (SiteListDTO sDto : storeDto.sites) {
                            vCount += sDto.visits != null ? sDto.visits.size() : 0;
                        }
                    }
                }
                dto.siteCount  = sCount;
                dto.visitCount = vCount;
                dtoList.add(dto);
            }

            GroupListResult res = new GroupListResult();
            res.locationGroups = dtoList;
            res.summaryText = dtoList.isEmpty()
                ? 'No location groups found.'
                : (hasFilter && !dtoList.isEmpty()
                    ? 'Found ' + dtoList.size() + ' location group' + (dtoList.size() > 1 ? 's' : '') + ' matching \'' + req.groupName + '\'.'
                    : (hasFilter
                        ? 'No groups found matching \'' + req.groupName + '\'. Showing all ' + dtoList.size() + ' group' + (dtoList.size() > 1 ? 's' : '') + '.'
                        : 'Showing all ' + dtoList.size() + ' location group' + (dtoList.size() > 1 ? 's' : '') + '.'));
            results.add(res);
        }

        return results;
    }
}