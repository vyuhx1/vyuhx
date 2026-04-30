public class SiteLocatorImpl implements ISiteLocator {
    
    public String assessNearestSite(Decimal lat, Decimal lon, String addressText) {
        List<RetailStore> nearbySites = new List<RetailStore>();
        
        // Handle coordinate search (WhatsApp Pin) or text address
        if (lat != null && lon != null) {
            nearbySites = [
                SELECT Id, Name, Current_Demand_Score__c, Competition_Level__c, 
                       Estimated_Rent__c, Proposed_Square_Footage__c, RetailLocationGroup.Name
                FROM RetailStore
                WHERE DISTANCE(Site_Location__c, GEOLOCATION(:lat, :lon), 'km') < 5
                ORDER BY DISTANCE(Site_Location__c, GEOLOCATION(:lat, :lon), 'km') ASC
                LIMIT 1
            ];
        } else if (String.isNotBlank(addressText)) {
            String searchKey = '%' + addressText + '%';
            nearbySites = [
                SELECT Id, Name, Current_Demand_Score__c, Competition_Level__c, 
                       Estimated_Rent__c, Proposed_Square_Footage__c, RetailLocationGroup.Name
                FROM RetailStore
                WHERE Name LIKE :searchKey
                LIMIT 1
            ];
        }
        if (nearbySites.isEmpty()) {
            return 'I could not find any proposed expansion sites within a 5km radius of that location.';
        }
        RetailStore site = nearbySites[0];
        // --- Automate CGC Field Execution ---
        // Create a Visit record to prove the surveyor was physically assessing the site
        Visit newVisit = new Visit();
        newVisit.PlaceId = site.Id;
        newVisit.PlannedVisitStartTime = System.now();
        newVisit.Status = 'Planned';
        newVisit.VisitPriority = 'High';
        insert newVisit;
        // --- Calculate Financials ---
        Decimal monthlyRev = (site.Proposed_Square_Footage__c != null ? site.Proposed_Square_Footage__c : 0) * 800;
        Decimal annualRevenue = monthlyRev * 12;
        Decimal annualProfit = annualRevenue * 0.20; 
        Decimal capEx = site.Estimated_Rent__c * 6; 
        Decimal paybackPeriod = annualProfit > 0 ? (capEx / annualProfit) : 0;
        // --- Format the Output ---
        return 'Field Site Assessed: ' + site.Name + '\n' +
               'A Visit record has been logged in Consumer Goods Cloud for your assessment.\n\n' +
               ' Site Scorecard:\n' +
               '- Demand Score: ' + site.Current_Demand_Score__c + '\n' +
               '- Competition: ' + site.Competition_Level__c + '\n' +
               '- Est. Annual Revenue: ₹' + annualRevenue.setScale(2) + '\n' +
               '- Payback Period: ' + paybackPeriod.setScale(1) + ' Years';
    }
}