public without sharing class VisitDashboardController {

    @AuraEnabled(cacheable=true)
    public static List<VisitDashboardDTO> getUpcomingVisits() {
        Id userId = UserInfo.getUserId();

        List<Visit> visits = [
            SELECT Id, ContextId, Context.Name,
                   VisitorId, Visitor.Name,
                   Status, VisitPriority,
                   PlannedVisitStartTime, PlannedVisitEndTime,
                   ActualVisitStartTime,  ActualVisitEndTime
            FROM   Visit
            WHERE  VisitorId = :userId
            ORDER BY PlannedVisitStartTime ASC NULLS LAST
            LIMIT  50
        ];

        // Separate Sites__c query — polymorphic Context prevents direct traversal
        Set<Id> contextIds = new Set<Id>();
        for (Visit v : visits) {
            if (v.ContextId != null) contextIds.add(v.ContextId);
        }

        Map<Id, Sites__c> siteMap = new Map<Id, Sites__c>();
        if (!contextIds.isEmpty()) {
            for (Sites__c s : [
                SELECT Id,
                       Retail_Store__r.Name,
                       Retail_Store__r.RetailLocationGroup.Name,
                       Proposed_Site_Location__Latitude__s,
                       Proposed_Site_Location__Longitude__s,
                       Site_Address__Latitude__s,
                       Site_Address__Longitude__s
                FROM   Sites__c
                WHERE  Id IN :contextIds
            ]) {
                siteMap.put(s.Id, s);
            }
        }

        List<VisitDashboardDTO> results = new List<VisitDashboardDTO>();
        for (Visit v : visits) {
            VisitDashboardDTO dto = new VisitDashboardDTO();
            dto.visitId     = v.Id;
            dto.siteName    = v.Context != null ? v.Context.Name : 'N/A';
            Sites__c site   = siteMap.get(v.ContextId);
            dto.retailStore = (site != null && site.Retail_Store__r != null)
                              ? site.Retail_Store__r.Name : null;
            dto.groupName   = (site != null && site.Retail_Store__r != null
                               && site.Retail_Store__r.RetailLocationGroup != null)
                              ? site.Retail_Store__r.RetailLocationGroup.Name : null;
            dto.visitorName = v.Visitor != null ? v.Visitor.Name : 'Unassigned';
            dto.status      = v.Status;
            dto.priority    = v.VisitPriority;
            dto.plannedStart = v.PlannedVisitStartTime != null
                               ? v.PlannedVisitStartTime.format('dd MMM yyyy HH:mm') : null;
            dto.plannedEnd   = v.PlannedVisitEndTime != null
                               ? v.PlannedVisitEndTime.format('dd MMM yyyy HH:mm')   : null;
            dto.actualStart  = v.ActualVisitStartTime != null
                               ? v.ActualVisitStartTime.format('dd MMM yyyy HH:mm')  : null;
            dto.actualEnd    = v.ActualVisitEndTime != null
                               ? v.ActualVisitEndTime.format('dd MMM yyyy HH:mm')    : null;
            if (site != null) {
                dto.latitude  = site.Proposed_Site_Location__Latitude__s  != null
                                ? site.Proposed_Site_Location__Latitude__s
                                : site.Site_Address__Latitude__s;
                dto.longitude = site.Proposed_Site_Location__Longitude__s != null
                                ? site.Proposed_Site_Location__Longitude__s
                                : site.Site_Address__Longitude__s;
            }
            results.add(dto);
        }
        return results;
    }
}