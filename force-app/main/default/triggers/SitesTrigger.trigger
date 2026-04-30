trigger SitesTrigger on Sites__c (after insert, after update) {
    List<ReverseGeocodeQueueable.SiteRequest> pending = new List<ReverseGeocodeQueueable.SiteRequest>();

    for (Sites__c site : Trigger.new) {
        // Only process records that have coordinates
        if (site.Proposed_Site_Location__Latitude__s == null
            || site.Proposed_Site_Location__Longitude__s == null) {
            continue;
        }

        // On update, skip if coordinates haven't changed
        if (Trigger.isUpdate) {
            Sites__c old = Trigger.oldMap.get(site.Id);
            if (old.Proposed_Site_Location__Latitude__s  == site.Proposed_Site_Location__Latitude__s
                && old.Proposed_Site_Location__Longitude__s == site.Proposed_Site_Location__Longitude__s) {
                continue;
            }
        }

        pending.add(new ReverseGeocodeQueueable.SiteRequest(
            site.Id,
            site.Proposed_Site_Location__Latitude__s,
            site.Proposed_Site_Location__Longitude__s
        ));
    }

    if (!pending.isEmpty() && !System.isQueueable() && !System.isBatch() && !System.isFuture()) {
        System.enqueueJob(new ReverseGeocodeQueueable(pending));
    }
}