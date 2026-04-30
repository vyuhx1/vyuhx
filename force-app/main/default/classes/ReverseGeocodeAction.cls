public with sharing class ReverseGeocodeAction {

    @InvocableMethod(
        label='Reverse Geocode Coordinates'
        description='Enqueues an async job to call Geoapify and write address components back to Sites__c.Site_Address__c.'
    )
    public static void reverseGeocode(List<GeocodeRequest> requests) {
        List<ReverseGeocodeQueueable.SiteRequest> pending = new List<ReverseGeocodeQueueable.SiteRequest>();
        for (GeocodeRequest req : requests) {
            if (req.siteId != null && req.latitude != null && req.longitude != null) {
                pending.add(new ReverseGeocodeQueueable.SiteRequest(req.siteId, req.latitude, req.longitude));
            }
        }
        if (!pending.isEmpty()) {
            System.enqueueJob(new ReverseGeocodeQueueable(pending));
        }
    }

    // ── Input ──────────────────────────────────────────────────────────────────

    public class GeocodeRequest {
        @InvocableVariable(label='Site Record Id' required=true)
        public Id siteId;

        @InvocableVariable(label='Latitude' required=true)
        public Decimal latitude;

        @InvocableVariable(label='Longitude' required=true)
        public Decimal longitude;
    }
}