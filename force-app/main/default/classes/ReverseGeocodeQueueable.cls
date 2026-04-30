public class ReverseGeocodeQueueable implements Queueable, Database.AllowsCallouts {

    private static final Integer CHUNK_SIZE = 100;

    // ── Inner DTO ───────────────────────────────────────────────────────────────

    public class SiteRequest {
        public Id      siteId;
        public Decimal latitude;
        public Decimal longitude;

        public SiteRequest(Id siteId, Decimal latitude, Decimal longitude) {
            this.siteId    = siteId;
            this.latitude  = latitude;
            this.longitude = longitude;
        }
    }

    // ── State ──────────────────────────────────────────────────────────────────

    private List<SiteRequest> pending;

    public ReverseGeocodeQueueable(List<SiteRequest> pending) {
        this.pending = pending;
    }

    // ── Execute ────────────────────────────────────────────────────────────────

    public void execute(QueueableContext ctx) {
        if (pending == null || pending.isEmpty()) {
            return;
        }

        Geocoding_Config__mdt config = Geocoding_Config__mdt.getInstance('Geoapify');
        if (config == null || String.isBlank(config.Api_Key__c)) {
            System.debug(LoggingLevel.ERROR, 'ReverseGeocodeQueueable: Geoapify config missing.');
            return;
        }

        // Slice current chunk — process up to CHUNK_SIZE records
        Integer chunkEnd  = Math.min(CHUNK_SIZE, pending.size());
        List<SiteRequest> chunk    = new List<SiteRequest>();
        List<SiteRequest> overflow = new List<SiteRequest>();

        for (Integer i = 0; i < pending.size(); i++) {
            if (i < chunkEnd) {
                chunk.add(pending[i]);
            } else {
                overflow.add(pending[i]);
            }
        }

        List<Sites__c> toUpdate = new List<Sites__c>();

        for (SiteRequest current : chunk) {
            try {
                String endpoint = 'https://api.geoapify.com/v1/geocode/reverse'
                    + '?lat='    + EncodingUtil.urlEncode(String.valueOf(current.latitude),  'UTF-8')
                    + '&lon='    + EncodingUtil.urlEncode(String.valueOf(current.longitude), 'UTF-8')
                    + '&format=json'
                    + '&apiKey=' + EncodingUtil.urlEncode(config.Api_Key__c, 'UTF-8');

                HttpRequest req = new HttpRequest();
                req.setEndpoint(endpoint);
                req.setMethod('GET');
                req.setHeader('Accept', 'application/json');
                req.setTimeout(10000);

                HttpResponse res = new Http().send(req);

                if (res.getStatusCode() != 200) {
                    System.debug(LoggingLevel.ERROR,
                        'ReverseGeocodeQueueable: HTTP ' + res.getStatusCode() + ' for site ' + current.siteId);
                    continue;
                }

                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> results = (List<Object>) body.get('results');
                if (results == null || results.isEmpty()) {
                    continue;
                }

                Map<String, Object> first = (Map<String, Object>) results[0];

                String houseNum  = (String) first.get('housenumber');
                String streetVal = (String) first.get('street');
                String street    = ((houseNum != null ? houseNum + ' ' : '') +
                                    (streetVal != null ? streetVal : '')).trim();
                String city = (String) first.get('city');
                if (String.isBlank(city)) {
                    city = (String) first.get('county');
                }
                String state       = (String) first.get('state_code');
                String postalCode  = (String) first.get('postcode');
                String countryCode = (String) first.get('country_code');
                if (countryCode != null) {
                    countryCode = countryCode.toUpperCase();
                }

                Sites__c site = new Sites__c(Id = current.siteId);
                site.Site_Address__Street__s      = street;
                site.Site_Address__City__s        = city;
                site.Site_Address__StateCode__s   = state;
                site.Site_Address__PostalCode__s  = postalCode;
                site.Site_Address__CountryCode__s = countryCode;
                toUpdate.add(site);

            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'ReverseGeocodeQueueable: failed for site ' + current.siteId + ' — ' + e.getMessage());
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }

        // Chain next chunk if overflow remains
        // (trigger guard System.isQueueable() prevents re-entry from the update above)
        if (!overflow.isEmpty()) {
            System.enqueueJob(new ReverseGeocodeQueueable(overflow));
        }
    }
}