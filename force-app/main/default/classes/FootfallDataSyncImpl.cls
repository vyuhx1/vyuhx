public class FootfallDataSyncImpl implements IDataSyncOperation {
    private static Decimal toDecimal(Object rawValue) {
        if (rawValue == null) {
            return null;
        }
        if (rawValue instanceof Decimal) {
            return (Decimal) rawValue;
        }
        String valueAsString = String.valueOf(rawValue);
        if (String.isBlank(valueAsString)) {
            return null;
        }
        return Decimal.valueOf(valueAsString);
    }

    private static String toStringValue(Object rawValue) {
        return rawValue == null ? null : String.valueOf(rawValue);
    }

    public void executeSync() {
        // --- Query 1: DemandScoreFinal__cio ---
        ConnectApi.CdpQueryInput q1 = new ConnectApi.CdpQueryInput();
        q1.sql = 'SELECT Demand_Score__c, City__c, Area__c, SubArea__c, Footfall_Index__c, Demographic_Score__c, Pincode__c, UniqueId__c FROM DemandScoreFinal__cio';
        ConnectApi.CdpQueryOutputV2 demandResponse;
        try {
            demandResponse = ConnectApi.CdpQuery.queryAnsiSqlV2(q1);
            System.debug('DemandScoreFinal response: ' + demandResponse);
        } catch (Exception e) {
            System.debug('DemandScoreFinal query failed: ' + e.getMessage());
            return;
        }

        // --- Query 2: POS_Metrics__cio ---
        ConnectApi.CdpQueryInput q2 = new ConnectApi.CdpQueryInput();
        q2.sql = 'SELECT EBITDA_Margin__c, Area__c, SubArea__c, Payback_Period_Years__c, Expected_Annual_Revenue__c, Pincode__c, UniqueId__c FROM POS_Metrics__cio';
        ConnectApi.CdpQueryOutputV2 posResponse;
        try {
            posResponse = ConnectApi.CdpQuery.queryAnsiSqlV2(q2);
            System.debug('POS_Metrics response: ' + posResponse);
        } catch (Exception e) {
            System.debug('POS_Metrics query failed: ' + e.getMessage());
            return;
        }

        // --- Query 3: Competition_Metrics__cio ---
        ConnectApi.CdpQueryInput q3 = new ConnectApi.CdpQueryInput();
        q3.sql = 'SELECT Distance_From_Location_KM__c, Area__c, SubArea__c, Outlet_Format__c, Proposed_Site_Latitude__c, Proposed_Site_Longitude__c, Competition_Level__c, Competition_Activity__c, Competition_Confidence__c, Competition_Impact__c, Competitor_Outlet_ID__c, Pincode__c, UniqueId__c FROM Competition_Metrics__cio';
        ConnectApi.CdpQueryOutputV2 compResponse;
        try {
            compResponse = ConnectApi.CdpQuery.queryAnsiSqlV2(q3);
            System.debug('Competition_Metrics response: ' + compResponse);
        } catch (Exception e) {
            System.debug('Competition_Metrics query failed: ' + e.getMessage());
            return;
        }

        // --- Process DemandScoreFinal data (keyed by UniqueId__c) ---
        Map<String, Decimal> uidToDemandScoreMap      = new Map<String, Decimal>();
        Map<String, Decimal> uidToFootfallIndexMap    = new Map<String, Decimal>();
        Map<String, Decimal> uidToDemographicScoreMap = new Map<String, Decimal>();
        Map<String, String>  uidToGroupNameMap        = new Map<String, String>();
        Map<String, String>  uidToStoreNameMap        = new Map<String, String>();
        Map<String, String>  uidToSubAreaMap          = new Map<String, String>();
        Map<String, String>  uidToCityMap             = new Map<String, String>();
        Map<String, String>  groupNameToAreaMap       = new Map<String, String>();
        Map<String, String>  groupNameToPincodeMap    = new Map<String, String>();
        Set<String>          groupNameSet             = new Set<String>();
        Set<String>          allUniqueIds             = new Set<String>();

        for (ConnectApi.CdpQueryV2Row row : demandResponse.data) {
            Decimal score            = toDecimal(row.rowData[0]);
            String  city             = toStringValue(row.rowData[1]);
            String  area             = toStringValue(row.rowData[2]);
            String  subArea          = toStringValue(row.rowData[3]);
            Decimal footfallIndex    = toDecimal(row.rowData[4]);
            Decimal demographicScore = toDecimal(row.rowData[5]);
            String  pincode          = toStringValue(row.rowData[6]);
            String  uniqueId         = toStringValue(row.rowData[7]);

            String groupName = city + ' - ' + area;
            String storeName = subArea;

            uidToDemandScoreMap.put(uniqueId, score);
            uidToFootfallIndexMap.put(uniqueId, footfallIndex);
            uidToDemographicScoreMap.put(uniqueId, demographicScore);
            uidToGroupNameMap.put(uniqueId, groupName);
            uidToStoreNameMap.put(uniqueId, storeName);
            uidToSubAreaMap.put(uniqueId, subArea);
            uidToCityMap.put(uniqueId, city);
            groupNameToAreaMap.put(groupName, area);
            groupNameToPincodeMap.put(groupName, pincode);
            groupNameSet.add(groupName);
            allUniqueIds.add(uniqueId);
        }

        if (allUniqueIds.isEmpty()) return;

        // --- Process POS_Metrics data (keyed by UniqueId__c) ---
        // rowData[0]=EBITDA_Margin__c, [1]=Area__c, [2]=SubArea__c,
        // [3]=Payback_Period_Years__c, [4]=Expected_Annual_Revenue__c ,
        // [5]=Pincode__c, [6]=UniqueId__c
        Map<String, Decimal> uidToEbitdaMap  = new Map<String, Decimal>();
        Map<String, Decimal> uidToPaybackMap = new Map<String, Decimal>();
        Map<String, Decimal> uidToExpectedRevenueMap = new Map<String, Decimal>();

        for (ConnectApi.CdpQueryV2Row row : posResponse.data) {
            String  uniqueId = toStringValue(row.rowData[6]);
            uidToEbitdaMap.put(uniqueId, toDecimal(row.rowData[0]));
            uidToPaybackMap.put(uniqueId, toDecimal(row.rowData[3]));
            uidToExpectedRevenueMap.put(uniqueId, toDecimal(row.rowData[4]));
        }

        // --- Process Competition_Metrics data (multiple rows per UniqueId__c → Sites__c) ---
        // rowData[0]=Distance_From_Location_KM__c, [1]=Area__c, [2]=SubArea__c,
        // [3]=Outlet_Format__c (no Sites__c field — skipped),
        // [4]=Proposed_Site_Latitude__c, [5]=Proposed_Site_Longitude__c,
        // [6]=Competition_Level__c, [7]=Competition_Activity__c,
        // [8]=Competition_Confidence__c, [9]=Competition_Impact__c,
        // [10]=Competitor_Outlet_ID__c (External ID on Sites__c — upsert key),
        // [11]=Pincode__c, [12]=UniqueId__c
        Map<String, List<Map<String, Object>>> uidToCompRowsMap = new Map<String, List<Map<String, Object>>>();

        for (ConnectApi.CdpQueryV2Row row : compResponse.data) {
            String uniqueId = toStringValue(row.rowData[12]);
            if (!uidToCompRowsMap.containsKey(uniqueId)) {
                uidToCompRowsMap.put(uniqueId, new List<Map<String, Object>>());
            }
            uidToCompRowsMap.get(uniqueId).add(new Map<String, Object>{
                'distanceKm'         => toDecimal(row.rowData[0]),
                'lat'                => toDecimal(row.rowData[4]),
                'lng'                => toDecimal(row.rowData[5]),
                'compLevel'          => toDecimal(row.rowData[6]),
                'compActivity'       => toDecimal(row.rowData[7]),
                'compConfidence'     => toDecimal(row.rowData[8]),
                'compImpact'         => toDecimal(row.rowData[9]),
                'competitorOutletId' => toStringValue(row.rowData[10])
            });
        }

        // --- Upsert RetailLocationGroups ---
        Map<String, RetailLocationGroup> existingGroupByName = new Map<String, RetailLocationGroup>();
        for (RetailLocationGroup rlg : [
            SELECT Id, Name FROM RetailLocationGroup WHERE Name IN :groupNameSet
        ]) {
            existingGroupByName.put(rlg.Name, rlg);
        }

        List<RetailLocationGroup> groupsToUpsert = new List<RetailLocationGroup>();
        for (String groupName : groupNameSet) {
            if (existingGroupByName.containsKey(groupName)) {
                groupsToUpsert.add(new RetailLocationGroup(
                    Id         = existingGroupByName.get(groupName).Id,
                    Area__c    = groupNameToAreaMap.get(groupName),
                    Pincode__c = groupNameToPincodeMap.get(groupName)
                ));
            } else {
                groupsToUpsert.add(new RetailLocationGroup(
                    Name       = groupName,
                    Area__c    = groupNameToAreaMap.get(groupName),
                    Pincode__c = groupNameToPincodeMap.get(groupName)
                ));
            }
        }

        if (!groupsToUpsert.isEmpty()) {
            upsert groupsToUpsert;
        }

        // Refresh group map with newly created Ids
        for (RetailLocationGroup rlg : [
            SELECT Id, Name FROM RetailLocationGroup WHERE Name IN :groupNameSet
        ]) {
            existingGroupByName.put(rlg.Name, rlg);
        }

        // --- Upsert RetailStores (identified by UniqueId__c) ---
        Id accountId = [SELECT Id FROM Account WHERE Name = 'Global Mega Mart'].Id;

        Map<String, RetailStore> existingStoreByUniqueId = new Map<String, RetailStore>();
        for (RetailStore rs : [
            SELECT Id, UniqueId__c FROM RetailStore WHERE UniqueId__c IN :allUniqueIds
        ]) {
            existingStoreByUniqueId.put(rs.UniqueId__c, rs);
        }

        List<RetailStore> storesToUpsert = new List<RetailStore>();
        for (String uniqueId : allUniqueIds) {
            String groupName = uidToGroupNameMap.get(uniqueId);
            Id     groupId   = existingGroupByName.get(groupName).Id;

            RetailStore store;
            if (existingStoreByUniqueId.containsKey(uniqueId)) {
                store = new RetailStore(Id = existingStoreByUniqueId.get(uniqueId).Id);
            } else {
                store = new RetailStore(
                    Name      = uidToStoreNameMap.get(uniqueId),
                    AccountId = accountId
                );
            }

            store.UniqueId__c             = uniqueId;
            store.SubArea__c              = uidToSubAreaMap.get(uniqueId);
            store.City__c                 = uidToCityMap.get(uniqueId);
            store.RetailLocationGroupId   = groupId;
            store.Current_Demand_Score__c = uidToDemandScoreMap.get(uniqueId);
            store.Footfall_Index__c       = uidToFootfallIndexMap.get(uniqueId);
            store.Demographic_Score__c    = uidToDemographicScoreMap.get(uniqueId);
            store.EBITDA_Margin__c        = uidToEbitdaMap.get(uniqueId);
            store.Payback_Period_Years__c = uidToPaybackMap.get(uniqueId);
            store.Expected_Annual_Revenue__c = uidToExpectedRevenueMap.get(uniqueId);

            storesToUpsert.add(store);
        }

        if (!storesToUpsert.isEmpty()) {
            upsert storesToUpsert;
        }

        // Refresh store map with newly created Ids
        for (RetailStore rs : [
            SELECT Id, UniqueId__c FROM RetailStore WHERE UniqueId__c IN :allUniqueIds
        ]) {
            existingStoreByUniqueId.put(rs.UniqueId__c, rs);
        }

        // --- Sync Sites__c from Competition_Metrics (upsert on Competitor_Outlet_ID__c) ---
        if (!uidToCompRowsMap.isEmpty()) {
            Map<String, Id> compUidToStoreIdMap = new Map<String, Id>();
            Map<String, string> compUidToSubAreaMap = new Map<String, string>();
            for (RetailStore rs : [
                SELECT Id, SubArea__c, UniqueId__c FROM RetailStore WHERE UniqueId__c IN :uidToCompRowsMap.keySet()
            ]) {
                compUidToStoreIdMap.put(rs.UniqueId__c, rs.Id);
                compUidToSubAreaMap.put(rs.UniqueId__c, rs.SubArea__c);
            }

            List<Sites__c> sitesToUpsert = new List<Sites__c>();
            
            for (String uniqueId : uidToCompRowsMap.keySet()) {
                if (!compUidToStoreIdMap.containsKey(uniqueId)) continue;

                Id storeId = compUidToStoreIdMap.get(uniqueId);
                string subArea = compUidToSubAreaMap.get(uniqueId);
                Integer siteCounter = 1;
                for (Map<String, Object> compData : uidToCompRowsMap.get(uniqueId)) {
                    Sites__c site = new Sites__c();
                    site.Name                               = subArea + ' - Site ' + siteCounter++;
                    site.Retail_Store__c                    = storeId;
                    site.Competitor_Outlet_ID__c            = (String)  compData.get('competitorOutletId');
                    site.Avg_Distance_from_Competitor__c    = (Decimal) compData.get('distanceKm');
                    site.Competition_Level__c               = (Decimal) compData.get('compLevel');
                    site.Competition_Activity__c            = (Decimal) compData.get('compActivity');
                    site.Competition_Confidence__c          = (Decimal) compData.get('compConfidence');
                    site.Competition_Impact__c              = (Decimal) compData.get('compImpact');

                    Decimal lat = (Decimal) compData.get('lat');
                    Decimal lng = (Decimal) compData.get('lng');
                    if (lat != null && lng != null) {
                        site.Proposed_Site_Location__latitude__s  = lat;
                        site.Proposed_Site_Location__longitude__s = lng;
                    }
                    sitesToUpsert.add(site);
                }
            }

            if (!sitesToUpsert.isEmpty()) {
                upsert sitesToUpsert Sites__c.Competitor_Outlet_ID__c;
            }
        }
    }
}