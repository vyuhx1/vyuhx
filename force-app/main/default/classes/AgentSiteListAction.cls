public class AgentSiteListAction {

    public class SiteRequest {
        @InvocableVariable(description='Optional site name filter. Leave blank to retrieve all sites.')
        public String siteName;
    }

    public class SiteListResult {
        @InvocableVariable(description='List of SiteListDTO objects, consumed by the siteList Lightning Type LWC.')
        public List<SiteListDTO> sites;

        @InvocableVariable(description='Plain-text summary for the agent chat response.')
        public String summaryText;
    }

    @InvocableMethod(label='Get Site List' description='Retrieves Sites__c records. Optionally filter by name — leave blank to get all. Includes related visits when available.')
    public static List<SiteListResult> getSites(List<SiteRequest> requests) {
        List<SiteListResult> results = new List<SiteListResult>();

        for (SiteRequest req : requests) {
            Boolean hasFilter = String.isNotBlank(req.siteName);
            String nameFilter = hasFilter ? '%' + req.siteName.trim() + '%' : null;

            List<Sites__c> siteRecords = hasFilter
                ? [
                    SELECT Id, Name, Status__c,
                           Competition_Level__c, Competition_Activity__c,
                           Competition_Confidence__c, Competition_Impact__c,
                           Avg_Distance_from_Competitor__c,
                           Proposed_Site_Location__latitude__s,
                           Proposed_Site_Location__longitude__s,
                           Retail_Store__c,
                           Retail_Store__r.Name, Retail_Store__r.City__c, Retail_Store__r.SubArea__c
                    FROM Sites__c
                    WHERE Name LIKE :nameFilter
                    ORDER BY Name
                    LIMIT 200
                  ]
                : [
                    SELECT Id, Name, Status__c,
                           Competition_Level__c, Competition_Activity__c,
                           Competition_Confidence__c, Competition_Impact__c,
                           Avg_Distance_from_Competitor__c,
                           Proposed_Site_Location__latitude__s,
                           Proposed_Site_Location__longitude__s,
                           Retail_Store__c,
                           Retail_Store__r.Name, Retail_Store__r.City__c, Retail_Store__r.SubArea__c
                    FROM Sites__c
                    ORDER BY Name
                    LIMIT 200
                  ];

            // Fall back to all sites if a filter was given but nothing matched
            if (siteRecords.isEmpty() && hasFilter) {
                siteRecords = [
                    SELECT Id, Name, Status__c,
                           Competition_Level__c, Competition_Activity__c,
                           Competition_Confidence__c, Competition_Impact__c,
                           Avg_Distance_from_Competitor__c,
                           Proposed_Site_Location__latitude__s,
                           Proposed_Site_Location__longitude__s,
                           Retail_Store__c,
                           Retail_Store__r.Name, Retail_Store__r.City__c, Retail_Store__r.SubArea__c
                    FROM Sites__c
                    ORDER BY Name
                    LIMIT 200
                ];
            }

            // Collect Sites__c Ids to fetch related visits (Visit.ContextId = Sites__c.Id)
            Set<Id> siteIds = new Set<Id>();
            for (Sites__c s : siteRecords) {
                siteIds.add(s.Id);
            }

            // Group visits by Sites__c Id (ContextId)
            Map<Id, List<SiteVisitDTO>> visitsBySiteId = new Map<Id, List<SiteVisitDTO>>();
            if (!siteIds.isEmpty()) {
                for (Visit v : [
                    SELECT Id, Name, Status, ActualVisitStartTime, ActualVisitEndTime, ContextId
                    FROM Visit
                    WHERE ContextId IN :siteIds
                    ORDER BY ActualVisitStartTime DESC
                    LIMIT 500
                ]) {
                    if (!visitsBySiteId.containsKey(v.ContextId)) {
                        visitsBySiteId.put(v.ContextId, new List<SiteVisitDTO>());
                    }
                    SiteVisitDTO vDto = new SiteVisitDTO();
                    vDto.visitId   = v.Id;
                    vDto.visitName = v.Name;
                    vDto.status    = v.Status;
                    vDto.startTime = v.ActualVisitStartTime != null
                        ? v.ActualVisitStartTime.format('MMM d, yyyy h:mm a')
                        : null;
                    vDto.endTime   = v.ActualVisitEndTime != null
                        ? v.ActualVisitEndTime.format('MMM d, yyyy h:mm a')
                        : null;
                    visitsBySiteId.get(v.ContextId).add(vDto);
                }
            }

            // Build DTOs
            List<SiteListDTO> dtoList = new List<SiteListDTO>();
            for (Sites__c s : siteRecords) {
                SiteListDTO dto = new SiteListDTO();
                dto.siteId               = s.Id;
                dto.siteName             = s.Name;
                dto.status               = s.Status__c;
                dto.competitionLevel     = s.Competition_Level__c;
                dto.competitionActivity  = s.Competition_Activity__c;
                dto.competitionConfidence = s.Competition_Confidence__c;
                dto.competitionImpact    = s.Competition_Impact__c;
                dto.distanceKm           = s.Avg_Distance_from_Competitor__c;
                dto.latitude             = s.Proposed_Site_Location__latitude__s;
                dto.longitude            = s.Proposed_Site_Location__longitude__s;
                dto.retailStoreId        = s.Retail_Store__c;
                dto.retailStoreName      = s.Retail_Store__r?.Name;
                dto.retailStoreCity      = s.Retail_Store__r?.City__c;
                dto.retailStoreSubArea   = s.Retail_Store__r?.SubArea__c;
                dto.visits               = visitsBySiteId.containsKey(s.Id)
                    ? visitsBySiteId.get(s.Id)
                    : new List<SiteVisitDTO>();
                dtoList.add(dto);
            }

            SiteListResult res = new SiteListResult();
            res.sites = dtoList;
            res.summaryText = dtoList.isEmpty()
                ? 'No sites found.'
                : (hasFilter && !siteRecords.isEmpty()
                    ? 'Found ' + dtoList.size() + ' site' + (dtoList.size() > 1 ? 's' : '') + ' matching \'' + req.siteName + '\'.'
                    : (hasFilter
                        ? 'No sites found matching \'' + req.siteName + '\'. Showing all ' + dtoList.size() + ' site' + (dtoList.size() > 1 ? 's' : '') + '.'
                        : 'Showing all ' + dtoList.size() + ' site' + (dtoList.size() > 1 ? 's' : '') + '.'));
            results.add(res);
        }

        return results;
    }
}