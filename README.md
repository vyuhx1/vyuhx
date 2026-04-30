# VyuhX — Retail Store Expansion Intelligence

> AI-powered retail expansion platform built on Salesforce Consumer Goods Cloud, Agentforce, and Data Cloud.

VyuhX helps consumer goods companies decide **where** to open new retail stores and **how** to execute and track the field surveys that validate those decisions — end to end, on a single Salesforce platform.

---

## What It Does

- **Data Cloud** scores every proposed location daily using demand, footfall, POS, and competition data — synced live into CG Cloud
- **Agentforce** gives field surveyors a conversational AI interface to start visits, log field notes, and close out surveys — without touching a CRM form
- **A geospatial dashboard** gives expansion managers a live view of scored sites, active field visits, urgency alerts, and push notifications — all on a map

For full technical details, see [TECHNICAL_DESIGN.md](./TECHNICAL_DESIGN.md).

---

## Platform Requirements

| Requirement | Details |
|---|---|
| Salesforce CLI | `sf` v2+ |
| Salesforce API Version | 66.0 |
| CG Cloud | Consumer Goods Cloud enabled |
| Agentforce | Agentforce (Einstein Copilot) enabled |
| Data Cloud | Salesforce Data Cloud with CIO support |
| External API | Geoapify account (reverse geocoding) |

---

## Project Structure

```
force-app/
  main/default/
    classes/         - Apex: agent actions, services, DTOs, controllers
    lwc/             - Lightning Web Components: dashboard, visit cards, agent renderers
    triggers/        - SitesTrigger (reverse geocode), VisitTrigger (placeholder)
    flows/           - Visit activity, geocoding, routing, visit creation flows
    objects/         - Custom objects: Sites__c, Visit_Request__c + custom fields
    lightningTypes/  - Agentforce Lightning Type renderers (DTO to LWC mapping)
    customMetadata/  - Expansion_Dashboard_Setting__mdt, Geocoding_Config__mdt
manifest/
  package.xml        - Deployment manifest
TECHNICAL_DESIGN.md  - Full technical design document
```

---

## Setup & Deployment

### 1. Authenticate

```bash
sf org login web --alias vyuhx-org
```

### 2. Deploy Source

```bash
sf project deploy start --source-dir force-app --target-org vyuhx-org
```

### 3. Configure Custom Metadata

After deployment, set the following Custom Metadata records in your org:

| CMDT Object | Record | Field | Value |
|---|---|---|---|
| `Geocoding_Config__mdt` | `Geoapify` | `Api_Key__c` | Your Geoapify API key |
| `Expansion_Dashboard_Setting__mdt` | `Default_Settings` | `Minimum_Demand_Score__c` | e.g. `60` |

### 4. Assign Permission Sets

Assign the relevant permission sets to Expansion Managers and Field Surveyors.

### 5. Schedule Background Jobs

Run the following in Anonymous Apex to activate scheduled jobs:

```apex
// Data Cloud to CG Cloud daily sync (runs at midnight)
System.schedule('Data Cloud Sync', '0 0 0 * * ?', new DataCloudSyncScheduler());

// Visit notification alerts (runs every 6 hours)
System.schedule('Visit Notifications', '0 0 0/6 * * ?', new VisitNotificationScheduler());
```

### 6. Activate the Agent Actions

In **Setup > Agentforce > Agent Actions**, confirm all invocable actions are activated and linked to your agent topic.

---

## Agentforce Actions

| Action | What It Does |
|---|---|
| Assess Field Location | GPS pin to nearest site scorecard + auto Visit creation |
| Evaluate Proposed Retail Site | ROI + competition analysis for a store's sites |
| Look Up Visits | Multi-filter visit search (store, zone, status, date) |
| Get My Visits | Returns visits for the logged-in surveyor (identity-aware) |
| Log Visit Activity | Start / end a visit or attach field notes |
| Get Location Group List | Full zone to store to site to visit hierarchy |
| Get Retail Store List | Flat store list with nested sites and visits |
| Get Site List | Proposed site list with competition intelligence |
| Generate Store Summary | AI narrative via Einstein Prompt Template |
| Get Store Expansion Summary | Structured financial + AI summary for a store |
| Get Retail Store Details | Full store detail by name or Id |
| Get Store Context For Prompt | Builds context block for Prompt Template injection |
| Get Least Loaded Surveyor | Finds the least-loaded FieldSurveyor for assignment |

---

## Key Design Decisions

- **Polymorphic ContextId workaround** — `Visit.ContextId` cannot traverse custom relationships. All visit lookups resolve `Sites__c` IDs first, then filter visits by that ID set.
- **Dual output pattern** — Agent actions return both plain-text (spoken by agent) and a structured DTO (rendered as a Lightning Type card) in one call.
- **Identity-aware actions** — `Get My Visits` uses `UserInfo.getUserId()` internally; the agent never asks who the user is.
- **IST timestamps** — All visit activity timestamps are formatted in the `Asia/Kolkata` timezone via `DateTime.format()`.
- **Async reverse geocoding** — Coordinate changes on `Sites__c` trigger a chained Queueable that calls Geoapify in chunks of 100, guarded against recursive async re-queuing.

---

## License

[MIT](./LICENSE)


















TDD
# VyuhX — Technical Design Document

**Project:** `vyuhx`  
**API Version:** 66.0  
**Platform:** Salesforce CG Cloud + Agentforce + Data Cloud  
**Last Updated:** April 2026

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)  
2. [Architecture Overview](#2-architecture-overview)  
3. [Data Model](#3-data-model)  
4. [Data Cloud Objects](#4-data-cloud-objects)  
5. [Apex Layer](#5-apex-layer)  
6. [Agentforce Actions](#6-agentforce-actions)  
7. [LWC Components](#7-lwc-components)  
8. [Flows & Triggers](#8-flows--triggers)  
9. [Lightning Types (Agentforce Renderers)](#9-lightning-types-agentforce-renderers)  
10. [Key End-to-End Data Flows](#10-key-end-to-end-data-flows)  
11. [External Integrations](#11-external-integrations)  
12. [Dependency Map](#12-dependency-map)

---

## 1. Executive Summary

VyuhX is a **Retail Store Expansion Intelligence** platform built on Salesforce Consumer Goods Cloud (CG Cloud). It enables retail expansion teams and field surveyors to:

- Evaluate proposed expansion sites using AI-driven demand, footfall, demographic, and competition scoring
- Log field visit activity (start, notes, end) through Agentforce conversational AI or mobile
- Receive notifications for overdue and due-soon visits
- Sync enriched scoring data from Salesforce Data Cloud into CG Cloud retail store records
- View a geospatial intelligence dashboard of proposed sites and field activity

The system spans three platforms:
- **Salesforce CG Cloud** — standard objects (RetailStore, RetailLocationGroup, Visit), custom objects (Sites__c), flows, triggers
- **Agentforce** — 13+ invocable actions wired to a conversational AI agent, with Lightning Type renderers for rich output cards
- **Salesforce Data Cloud** — three Data Cloud query objects (`DemandScoreFinal__cio`, `POS_Metrics__cio`, `Competition_Metrics__cio`) used as the scoring data source

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          SALESFORCE DATA CLOUD                          │
│  DemandScoreFinal__cio │ POS_Metrics__cio │ Competition_Metrics__cio   │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │  ConnectApi.CdpQuery (ANSI SQL)
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                   APEX SYNC LAYER (scheduled daily)                     │
│  DataCloudSyncScheduler → FootfallDataSyncImpl → RetailStore update     │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    SALESFORCE CG CLOUD (Core Data)                      │
│                                                                         │
│  RetailLocationGroup ──< RetailStore ──< Sites__c                       │
│                                │                                        │
│                                └──< Visit (CG Cloud standard)           │
│                                          └──> ContentNote               │
│                                                                         │
└───────────────┬─────────────────────────────────────────────────────────┘
                │
       ┌────────┴──────────────────────────────────────────┐
       │  AGENTFORCE LAYER                                  │
       │                                                   │
       │  Agent Actions (InvocableMethods)                 │
       │  ├── AgentFieldAssessorAction                     │
       │  ├── AgentSiteEvaluatorAction                     │
       │  ├── AgentVisitLookupAction                       │
       │  ├── AgentLocationGroupListAction                  │
       │  ├── AgentRetailStoreListAction                   │
       │  ├── AgentSiteListAction                          │
       │  ├── AgentStoreSummaryAction                      │
       │  ├── GetMyVisitsAction                            │
       │  ├── LogVisitActivityAction                       │
       │  ├── AssignLeastLoadedSurveyorAction              │
       │  ├── StoreContextForPromptAction                  │
       │  ├── UpdateSiteStatusAction                       │
       │  ├── RetailStoreDetailsAction                     │
       │  └── StoreExpansionSummaryAction                  │
       │                                                   │
       │  Lightning Types (DTO → LWC renderer mapping)     │
       │  ├── Visit_Response         → visitList           │
       │  ├── My_Visits_Response     → myVisitDetails      │
       │  ├── Site_Evaluation_Response → siteEvaluationList│
       │  ├── Site_List_Response     → (siteList LWC)      │
       │  ├── Location_Group_List_Response → (LWC)         │
       │  ├── Retail_Store_List_Response → (LWC)           │
       │  └── Store_Summary_Response → (storeSummaryCard)  │
       └───────────────────────────────────────────────────┘
                │
       ┌────────┴──────────────────────────────────────────┐
       │  LWC UI LAYER (Lightning App Pages)               │
       │  storeExpansionDashboard (main intelligence panel) │
       │  visitDashboard + visitDashboardCard              │
       │  visitCard, visitList, myVisitDetails             │
       │  myVisitCard, siteEvaluationCard, siteDetailPanel │
       └───────────────────────────────────────────────────┘
```

---

## 3. Data Model

### 3.1 Standard CG Cloud Objects

#### `RetailLocationGroup`
Represents a geographic zone/cluster of retail stores.

| Field | Type | Description |
|---|---|---|
| `Name` | Text | Zone name (e.g. "Hyderabad North") |
| `Area__c` | Text | Area descriptor |
| `Pincode__c` | Text | Zone pincode |

#### `RetailStore`
Core entity — an actual or proposed retail store location.

| Field | Type | Purpose |
|---|---|---|
| `Name` | Text | Store name |
| `City__c` | Text | City |
| `SubArea__c` | Text | Sub-area/locality |
| `RetailLocationGroupId` | Lookup | Parent zone |
| `Current_Demand_Score__c` | Number | Composite demand score (synced from Data Cloud) |
| `Footfall_Index__c` | Number | Footfall index (synced from Data Cloud) |
| `Demographic_Score__c` | Number | Demographic score (synced from Data Cloud) |
| `Expected_Annual_Revenue__c` | Currency | Projected annual revenue |
| `EBITDA_Margin__c` | Percent | Projected EBITDA margin |
| `Payback_Period_Years__c` | Number | Capital payback period in years |
| `Competition_Level__c` | Picklist | Competitive density assessment |
| `UniqueId__c` | Text | External key for Data Cloud sync matching |

#### `Visit` (CG Cloud Standard)
Field visit record linking a surveyor to a proposed site.

| Field | Type | Purpose |
|---|---|---|
| `ContextId` | Polymorphic Lookup | Points to `Sites__c` record |
| `VisitorId` | Lookup (User) | Assigned field surveyor |
| `Status` | Picklist | `Planned` → `InProgress` → `Completed` / `Cancelled` |
| `VisitPriority` | Picklist | High / Medium / Low |
| `PlannedVisitStartTime` | DateTime | Scheduled start |
| `PlannedVisitEndTime` | DateTime | Scheduled end |
| `ActualVisitStartTime` | DateTime | When surveyor started |
| `ActualVisitEndTime` | DateTime | When surveyor completed |
| `StatusRemarks` | Text | Surveyor remarks |
| `InstructionDescription` | Text | Pre-visit instructions |

---

### 3.2 Custom Objects

#### `Sites__c`
A proposed expansion site linked to a parent `RetailStore`. Multiple sites can exist per store.

| Field | Type | Purpose |
|---|---|---|
| `Retail_Store__c` | Lookup (RetailStore) | Parent retail store |
| `Proposed_Site_Location__c` | Geolocation | Coordinates of proposed site |
| `Site_Address__c` | Address | Reverse-geocoded address |
| `Status__c` | Picklist | `Planned` / `In Survey` / `Survey Completed` |
| `Competition_Level__c` | Picklist | Local competition level |
| `Competition_Activity__c` | Text | Description of competitor activity |
| `Competition_Confidence__c` | Percent | Confidence in competition data |
| `Competition_Impact__c` | Text | Projected impact of competition |
| `Competitor_Outlet_ID__c` | Text | External competitor reference |

---

## 4. Data Cloud Objects

Three Data Cloud Calculated Insight Objects (CIOs) are queried via `ConnectApi.CdpQuery.queryAnsiSqlV2()` by `FootfallDataSyncImpl`:

| CIO | Fields | Purpose |
|---|---|---|
| `DemandScoreFinal__cio` | `Demand_Score__c`, `City__c`, `Area__c`, `SubArea__c`, `Footfall_Index__c`, `Demographic_Score__c`, `Pincode__c`, `UniqueId__c` | Composite demand + footfall + demographic scoring per area |
| `POS_Metrics__cio` | `EBITDA_Margin__c`, `Area__c`, `SubArea__c`, `Payback_Period_Years__c`, `Expected_Annual_Revenue__c`, `Pincode__c`, `UniqueId__c` | POS-based financial projections |
| `Competition_Metrics__cio` | `Distance_From_Location_KM__c`, `Area__c`, `SubArea__c`, `Outlet_Format__c`, `Proposed_Site_Latitude__c`, `Proposed_Site_Longitude__c`, `Competition_Level__c`, `Competition_Activity__c`, `Competition_Confidence__c`, `Competition_Impact__c`, `Competitor_Outlet_ID__c`, `Pincode__c`, `UniqueId__c` | Competitor proximity and impact metrics |

**Sync mechanism:** All three CIOs are queried by `FootfallDataSyncImpl.executeSync()`, results are matched to `RetailStore` records via `UniqueId__c`, and scores are written back to CG Cloud fields (`Current_Demand_Score__c`, `Footfall_Index__c`, `EBITDA_Margin__c`, etc.). The scheduler `DataCloudSyncScheduler` runs this daily as a scheduled Apex job.

**`FootfallDataSyncImpl.cls`** — three sequential Data Cloud queries via `ConnectApi`:

```apex
public void executeSync() {
    // Query 1: Demand, footfall & demographic scores
    ConnectApi.CdpQueryInput q1 = new ConnectApi.CdpQueryInput();
    q1.sql = 'SELECT Demand_Score__c, City__c, Area__c, SubArea__c,'
           + ' Footfall_Index__c, Demographic_Score__c, Pincode__c, UniqueId__c'
           + ' FROM DemandScoreFinal__cio';
    ConnectApi.CdpQueryOutputV2 demandResponse = ConnectApi.CdpQuery.queryAnsiSqlV2(q1);

    // Query 2: POS financial projections
    ConnectApi.CdpQueryInput q2 = new ConnectApi.CdpQueryInput();
    q2.sql = 'SELECT EBITDA_Margin__c, Payback_Period_Years__c,'
           + ' Expected_Annual_Revenue__c, UniqueId__c FROM POS_Metrics__cio';
    ConnectApi.CdpQueryOutputV2 posResponse = ConnectApi.CdpQuery.queryAnsiSqlV2(q2);

    // Query 3: Competitor proximity & impact metrics
    ConnectApi.CdpQueryInput q3 = new ConnectApi.CdpQueryInput();
    q3.sql = 'SELECT Distance_From_Location_KM__c, Competition_Level__c,'
           + ' Competition_Activity__c, Competition_Confidence__c,'
           + ' Competition_Impact__c, Competitor_Outlet_ID__c, UniqueId__c'
           + ' FROM Competition_Metrics__cio';
    ConnectApi.CdpQueryOutputV2 compResponse = ConnectApi.CdpQuery.queryAnsiSqlV2(q3);

    // Match by UniqueId__c and upsert RetailStore records
    // ...
}
```

---

## 5. Apex Layer

### 5.1 Interfaces

| Interface | Contract |
|---|---|
| `ISiteLocator` | `assessNearestSite(Decimal lat, Decimal lon, String address) : String` |
| `ISiteEvaluator` | `evaluateSite(String storeName) : List<SiteEvaluationDTO>` |
| `IVisitLookup` | `lookupVisits(...)`, `countVisits(...)` |
| `IDataSyncOperation` | `executeSync()` |

**`IVisitLookup.cls`** — contract that `VisitLookupImpl` fulfils:

```apex
public interface IVisitLookup {
    /**
     * @param siteName            Filter by Sites__c name (Context.Name LIKE)
     * @param retailStoreName     Filter by RetailStore name
     * @param retailStoreGroupName Filter by RetailLocationGroup name
     * @param statusFilter        'Planned', 'InProgress', 'Completed', 'Cancelled' — null = all
     * @param dateFilter          'Today', 'Yesterday', or 'dd-MM-yyyy' — applied to ActualVisitEndTime
     */
    List<VisitDTO> lookupVisits(String siteName, String retailStoreName,
                                String retailStoreGroupName, String statusFilter,
                                String dateFilter);

    /**
     * Returns count of visits per Status for the same location + date filters.
     * statusFilter is intentionally excluded so all statuses are always counted.
     */
    Map<String, Integer> countVisits(String siteName, String retailStoreName,
                                     String retailStoreGroupName, String dateFilter);
}
```

### 5.2 Service Implementations

| Class | Implements | Key Behaviour |
|---|---|---|
| `SiteLocatorImpl` | `ISiteLocator` | GEOLOCATION SOQL within 5km radius; creates a `Visit` record on site assessment; calculates financials and returns scorecard text |
| `SiteEvaluatorImpl` | `ISiteEvaluator` | Queries `RetailStore` + nested `Sites__r` by name LIKE; maps to `SiteEvaluationDTO` list with ROI metrics |
| `VisitLookupImpl` | `IVisitLookup` | Dynamic SOQL with optional site/store/group/status/date filters; resolves polymorphic `Context` via separate `Sites__c` query; attaches `ContentNote` data via `ContentDocumentLink` |
| `FootfallDataSyncImpl` | `IDataSyncOperation` | Queries 3 Data Cloud CIOs via `ConnectApi`; matches by `UniqueId__c`; upserts scores to `RetailStore` records |

**`SiteLocatorImpl.cls`** — GEOLOCATION SOQL used to find the nearest RetailStore within 5 km, then auto-creates a Visit:

```apex
// Coordinate search (WhatsApp GPS Pin)
if (lat != null && lon != null) {
    nearbySites = [
        SELECT Id, Name, Current_Demand_Score__c, Competition_Level__c,
               Estimated_Rent__c, Proposed_Square_Footage__c, RetailLocationGroup.Name
        FROM   RetailStore
        WHERE  DISTANCE(Site_Location__c, GEOLOCATION(:lat, :lon), 'km') < 5
        ORDER BY DISTANCE(Site_Location__c, GEOLOCATION(:lat, :lon), 'km') ASC
        LIMIT  1
    ];
}

// Auto-create a Visit record to record the physical assessment
Visit newVisit     = new Visit();
newVisit.PlaceId   = site.Id;
newVisit.PlannedVisitStartTime = System.now();
newVisit.Status    = 'Planned';
newVisit.VisitPriority = 'High';
insert newVisit;
```

**`VisitLookupImpl.cls`** — dynamic SOQL strategy to work around the polymorphic `ContextId` constraint on Visit:

```apex
// Step 1: Resolve Sites__c IDs from the retail store / group filter
if (String.isNotBlank(retailStoreName)) {
    String key = '%' + retailStoreName + '%';
    for (Sites__c s : [
        SELECT Id FROM Sites__c
        WHERE Retail_Store__r.Name LIKE :key
    ]) { siteIds.add(s.Id); }
}

// Step 2: Dynamic SOQL on Visit
String soql =
    'SELECT Id, ContextId, Context.Name,'
  + '       VisitorId, Visitor.Name, Status, VisitPriority,'
  + '       PlannedVisitStartTime, PlannedVisitEndTime,'
  + '       ActualVisitStartTime, ActualVisitEndTime,'
  + '       StatusRemarks, InstructionDescription'
  + ' FROM Visit WHERE Id != null';

if (filterBySiteIds) soql += ' AND ContextId IN :siteIds';
if (String.isNotBlank(statusFilter)) soql += ' AND Status = :statusFilter';
if (dateStart != null) soql += ' AND ActualVisitEndTime >= :dateStart AND ActualVisitEndTime < :dateEnd';
soql += ' ORDER BY PlannedVisitStartTime DESC LIMIT 20';

List<Visit> visits = Database.query(soql);

// Step 3: Separate Sites__c query for hierarchy and coordinates
// (Custom relationship traversal is blocked through polymorphic Context)
for (Sites__c s : [
    SELECT Id, Retail_Store__r.Name,
           Retail_Store__r.RetailLocationGroup.Name,
           Proposed_Site_Location__Latitude__s,
           Proposed_Site_Location__Longitude__s
    FROM   Sites__c
    WHERE  Id IN :contextIds
]) { siteMap.put(s.Id, s); }
```

### 5.3 Controllers

| Class | Sharing | Purpose |
|---|---|---|
| `StoreExpansionController` | `with sharing` | AuraEnabled methods for `storeExpansionDashboard`: proposed sites (filtered by `Expansion_Dashboard_Setting__mdt`), sites for dashboard, store evaluation, recent field visits, visit notifications |
| `VisitDashboardController` | `without sharing` | AuraEnabled `getUpcomingVisits()` for `visitDashboard` LWC — returns `VisitDashboardDTO` list for current user |
| `StoreSummaryController` | — | Calls Einstein Prompt Template `Store_Agent_Summary`; returns `storeName` + AI-generated narrative |

**`StoreExpansionController.cls`** — `getProposedSites()` filters by CMDT threshold; `getRecentFieldVisits()` resolves sites before querying Visits:

```apex
@AuraEnabled(cacheable=true)
public static List<RetailStore> getProposedSites() {
    Expansion_Dashboard_Setting__mdt settings =
        Expansion_Dashboard_Setting__mdt.getInstance('Default_Settings');
    Decimal minDemand = settings != null && settings.Minimum_Demand_Score__c != null
        ? settings.Minimum_Demand_Score__c : 0;
    return [
        SELECT Id, Name, Current_Demand_Score__c, Competition_Level__c,
               Estimated_Rent__c, Payback_Period_Years__c, Expected_Annual_Revenue__c,
               Site_Location__latitude__s, Site_Location__longitude__s,
               RetailLocationGroup.Name
        FROM   RetailStore
        WHERE  Current_Demand_Score__c >= :minDemand
        WITH SECURITY_ENFORCED
        ORDER BY Current_Demand_Score__c DESC
    ];
}
```

### 5.4 DTOs (Data Transfer Objects)

| DTO Class | Fields | Used By |
|---|---|---|
| `VisitDTO` | visitId, siteId, siteName, retailStore, groupName, visitorName, status, priority, plannedStart/End, actualStart/End, statusRemarks, instructions, latitude, longitude, notes (List<VisitNoteDTO>) | `AgentVisitLookupAction`, `GetMyVisitsAction`, `VisitLookupImpl` |
| `VisitNoteDTO` | noteId, noteTitle, notePreview, lastModified | Nested in VisitDTO |
| `VisitResponseDTO` | visits (List<VisitDTO>), plannedCount, inProgressCount, completedCount, cancelledCount | `AgentVisitLookupAction`, `GetMyVisitsAction` → Lightning Types |
| `VisitDashboardDTO` | visitId, siteName, retailStore, groupName, visitorName, status, priority, plannedStart/End, actualStart/End, latitude, longitude | `VisitDashboardController` → `visitDashboard` LWC |
| `SiteEvaluationDTO` | siteId, siteName, zone, city, subArea, demandScore, footfallIndex, demographicScore, estimatedAnnualRevenue, ebitdaMargin, paybackPeriod, competitionLevel, proposedSites (List<SiteDetailDTO>) | `AgentSiteEvaluatorAction` → `Site_Evaluation_Response` Lightning Type |
| `SiteDetailDTO` | siteId, siteLabel, distanceKm, competitionLevel, competitionActivity, competitionConfidence, competitionImpact, latitude, longitude | Nested in SiteEvaluationDTO |
| `RetailLocationGroupDTO` | groupId, groupName, area, pincode, stores (List<RetailStoreListDTO>) | `AgentLocationGroupListAction` → `Location_Group_List_Response` Lightning Type |
| `RetailStoreListDTO` | storeId, storeName, city, subArea, groupName, area, pincode, demandScore, footfallIndex, demographicScore, ebitda, payback, sites (List<SiteListDTO>), visits (List<SiteVisitDTO>) | `AgentRetailStoreListAction`, `RetailStoreDetailsAction` |
| `SiteListDTO` | siteId, siteName, status, competitionLevel/Activity/Confidence/Impact, distanceKm, latitude, longitude, visits | `AgentSiteListAction` → `Site_List_Response` Lightning Type |
| `SiteVisitDTO` | visitId, visitName, status, priority | Nested in RetailStoreListDTO / SiteListDTO |
| `StoreSummaryDTO` | storeName, summary | `AgentStoreSummaryAction` → `Store_Summary_Response` Lightning Type |
| `StoreExpansionSummaryDTO` | storeName, city, subArea, locationGroupName, demandScore, footfallIndex, demographicScore, ebitdaMargin, paybackPeriod, totalSites, aiNarrative, sites (List<SiteSummaryItem>) | `StoreExpansionSummaryAction` |

**`VisitDTO.cls`** — the core data shape serialised into every Lightning Type card:

```apex
public class VisitDTO {
    public String  visitId;
    public String  siteId;        // ContextId (Sites__c) — for record navigation
    public String  siteName;      // Context.Name
    public String  retailStore;   // Context.Retail_Store__r.Name
    public String  groupName;     // Context.Retail_Store__r.RetailLocationGroup.Name
    public String  visitorName;
    public String  status;        // Planned | InProgress | Completed | Cancelled
    public String  priority;
    public String  plannedStart;
    public String  plannedEnd;
    public String  actualStart;
    public String  actualEnd;
    public String  statusRemarks;
    public String  instructions;
    public Decimal latitude;      // For client-side Maps URL
    public Decimal longitude;
    public List<VisitNoteDTO> notes; // Up to 3 most recent ContentNotes
}
```

**`VisitResponseDTO.cls`** — wrapper returned by lookup and "My Visits" actions:

```apex
public class VisitResponseDTO {
    public List<VisitDTO> visits;
    public Integer plannedCount;
    public Integer inProgressCount;
    public Integer completedCount;
    public Integer cancelledCount;
}
```

**`VisitNoteDTO.cls`** — note preview attached to each visit card:

```apex
public class VisitNoteDTO {
    public String noteId;
    public String noteTitle;
    public String notePreview;   // ContentNote.TextPreview — 255 chars plain text
    public String lastModified;  // Formatted: dd MMM yyyy HH:mm
}
```

### 5.5 Async / Scheduler Classes

| Class | Type | Purpose |
|---|---|---|
| `DataCloudSyncScheduler` | `Schedulable` | Scheduled entry point — calls `FootfallDataSyncImpl.executeSync()` |
| `ReverseGeocodeQueueable` | `Queueable`, `Database.AllowsCallouts` | Calls Geoapify REST API to reverse-geocode `Sites__c` coordinates → writes address to `Site_Address__c` |
| `VisitNotificationService` | Service | `sendVisitAlerts()` — bulk notification for overdue/due-soon visits; `sendAlertForVisit(Id)` — single visit notification using `Messaging.CustomNotification` |
| `VisitNotificationScheduler` | `Schedulable` | Schedules `VisitNotificationService.sendVisitAlerts()` |

**`DataCloudSyncScheduler.cls`** — thin scheduled wrapper:

```apex
global class DataCloudSyncScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        IDataSyncOperation footfallSync = new FootfallDataSyncImpl();
        footfallSync.executeSync();
    }
}
```

**`VisitNotificationService.cls`** — builds and sends a `Messaging.CustomNotification` for a single visit:

```apex
public static void sendAlertForVisit(Id visitId) {
    CustomNotificationType notifType = [
        SELECT Id FROM CustomNotificationType
        WHERE  DeveloperName = 'Visit_Alert' LIMIT 1
    ];
    Visit v = [
        SELECT Id, VisitorId, Context.Name, PlannedVisitStartTime, Status
        FROM   Visit WHERE Id = :visitId LIMIT 1
    ];

    Boolean isOverdue = v.PlannedVisitStartTime != null
                        && v.PlannedVisitStartTime < Datetime.now();

    Messaging.CustomNotification notification = new Messaging.CustomNotification();
    notification.setNotificationTypeId(notifType.Id);
    notification.setTargetId(v.Id);
    notification.setTitle(isOverdue ? 'Overdue Visit: ' + v.Context.Name
                                    : 'Visit Due Soon: ' + v.Context.Name);
    notification.setBody(isOverdue
        ? 'Your visit was scheduled for '
          + v.PlannedVisitStartTime.format('dd MMM yyyy HH:mm') + ' and is now overdue.'
        : 'Your visit is scheduled for '
          + v.PlannedVisitStartTime.format('dd MMM yyyy HH:mm') + '. Please prepare.');
    notification.send(new Set<String>{ v.VisitorId });
}
```

### 5.6 Utility Actions (non-Agentforce)

| Class | Purpose |
|---|---|
| `CreateContentNoteAction` | `@InvocableMethod` — creates a `ContentNote` and links it to a record via `ContentDocumentLink` |
| `ReverseGeocodeAction` | `@InvocableMethod` — enqueues `ReverseGeocodeQueueable` for Sites__c records with coordinates |
| `UpdateSiteStatusAction` | `@InvocableMethod` — updates `Site_Status__c` on Sites__c; called from flows and agent actions |
| `StoreContextForPromptAction` | `@InvocableMethod` — builds a structured plain-text store context block for injection into Einstein Prompt Templates |

---

## 6. Agentforce Actions

All actions below are `@InvocableMethod` classes exposed to the Agentforce agent.

| Action Class | Label | Input(s) | Output(s) | Purpose |
|---|---|---|---|---|
| `AgentFieldAssessorAction` | Assess Field Location via Coordinates | `latitude`, `longitude`, `address` | `fieldScorecard` (String) | Finds nearest RetailStore by GPS (5km GEOLOCATION SOQL) or name; creates a Visit; returns financial scorecard |
| `AgentSiteEvaluatorAction` | Evaluate Proposed Retail Site | `storeName` | `siteEvaluations` (List<SiteEvaluationDTO>), `summaryText` | ROI + competition analysis for matching sites |
| `AgentVisitLookupAction` | Look Up Visits | `siteName`, `retailStoreName`, `retailStoreGroupName`, `statusFilter`, `dateFilter` | `visitResponse` (VisitResponseDTO), `summaryText` | Multi-filter visit search with ContentNotes; returns rich structured DTO for Lightning Type rendering |
| `AgentLocationGroupListAction` | Get Location Group List | `groupName` (optional) | `locationGroups` (List<RetailLocationGroupDTO>), `summaryText` | Returns store group hierarchy with stores, sites, visits |
| `AgentRetailStoreListAction` | Get Retail Store List | `storeName` (optional) | `retailStores` (List<RetailStoreListDTO>), `summaryText` | Lists retail stores with nested sites and visits |
| `AgentSiteListAction` | Get Site List | `siteName` (optional) | `sites` (List<SiteListDTO>), `summaryText` | Lists Sites__c records with nested visits |
| `AgentStoreSummaryAction` | Generate Store Expansion Summary | `storeId` | `storeSummary` (StoreSummaryDTO), `summaryText` | Calls Einstein Prompt Template for AI narrative + structured summary |
| `GetMyVisitsAction` | Get My Visits | `statusFilter` (optional) | `visitSummary` (String), `visitResponse` (VisitResponseDTO) | Returns visits assigned to **running user** (via `UserInfo.getUserId()`); no user ID input needed; includes full DTO for rich card + plain text |
| `LogVisitActivityAction` | Log Visit Activity | `visitId`, `action` (start/end/update notes), `visitNotes` (optional) | `visitOutput` (String) | `start` → sets `ActualVisitStartTime = now()`, status = InProgress; `end` → sets `ActualVisitEndTime = now()`, status = Completed; `update notes` → attaches ContentNote only; all times shown in IST |
| `AssignLeastLoadedSurveyorAction` | Get Least Loaded FieldSurveyor | _(none)_ | `userId` (String) | Finds active FieldSurveyor profile user with fewest Planned/InProgress visits |
| `StoreContextForPromptAction` | Get Store Context For Prompt | `storeName` | `storeContext` (String) | Builds structured plain-text block of store + sites + visits for Einstein Prompt Template injection |
| `RetailStoreDetailsAction` | Get Retail Store Details | `storeIdOrName` | `retailStores` (List<RetailStoreListDTO>), `summaryText` | Returns single store details by Id or Name; falls back to all stores |
| `StoreExpansionSummaryAction` | Get Store Expansion Summary | `storeName` | `StoreExpansionSummaryDTO` | Structured summary + AI narrative for the expansion dashboard |

### 6.1 Key Action Code

**`AgentFieldAssessorAction.cls`** — delegates to `ISiteLocator` interface:

```apex
public class AgentFieldAssessorAction {
    public class LocationRequest {
        @InvocableVariable(description='Latitude from the WhatsApp GPS Pin')
        public Decimal latitude;
        @InvocableVariable(description='Longitude from the WhatsApp GPS Pin')
        public Decimal longitude;
        @InvocableVariable(description='Text address if user types instead of sending a pin')
        public String address;
    }

    public class LocationResult {
        @InvocableVariable(description='The resulting scorecard and visit confirmation')
        public String fieldScorecard;
    }

    @InvocableMethod(label='Assess Field Location via Coordinates'
        description='Finds nearest site based on GPS or address and logs a visit.')
    public static List<LocationResult> evaluate(List<LocationRequest> requests) {
        ISiteLocator locator = new SiteLocatorImpl();
        List<LocationResult> results = new List<LocationResult>();
        for (LocationRequest req : requests) {
            LocationResult res = new LocationResult();
            res.fieldScorecard = locator.assessNearestSite(req.latitude, req.longitude, req.address);
            results.add(res);
        }
        return results;
    }
}
```

**`AgentVisitLookupAction.cls`** — multi-filter lookup returning both a rich DTO and a spoken summary:

```apex
public class AgentVisitLookupAction {
    public class LookupRequest {
        @InvocableVariable(description='Name of the Sites__c record')
        public String siteName;
        @InvocableVariable(description='Retail Store name filter')
        public String retailStoreName;
        @InvocableVariable(description='Retail Store Group / Zone filter')
        public String retailStoreGroupName;
        @InvocableVariable(description='Planned | InProgress | Completed | Cancelled')
        public String statusFilter;
        @InvocableVariable(description='Today | Yesterday | dd-MM-yyyy')
        public String dateFilter;
    }

    public class LookupResult {
        @InvocableVariable
        public VisitResponseDTO visitResponse;  // → Visit_Response Lightning Type
        @InvocableVariable
        public String summaryText;              // → agent speech
    }

    @InvocableMethod(label='Look Up Visits')
    public static List<LookupResult> lookup(List<LookupRequest> requests) {
        IVisitLookup impl = new VisitLookupImpl();
        // calls impl.lookupVisits() + impl.countVisits() per request
        // ...
    }
}
```

**`GetMyVisitsAction.cls`** — uses `UserInfo` to identify the caller, returns two parallel outputs:

```apex
public without sharing class GetMyVisitsAction {
    public class Request {
        @InvocableVariable(label='Status Filter'
            description='Planned | InProgress | Completed | Cancelled. Blank = all.')
        public String statusFilter;
    }

    public class Result {
        @InvocableVariable(label='Visit Summary')
        public String visitSummary;          // plain-text for agent to speak

        @InvocableVariable(label='Visit Response')
        public VisitResponseDTO visitResponse; // → My_Visits_Response Lightning Type
    }

    @InvocableMethod(label='Get My Visits')
    public static List<Result> execute(List<Request> requests) {
        Id userId = UserInfo.getUserId(); // No user ID input needed
        // SOQL: Visit WHERE VisitorId = :userId [AND Status = :filter]
        // Separate Sites__c + ContentNote queries
        // Builds VisitResponseDTO + plain-text summary
    }
}
```

**`LogVisitActivityAction.cls`** — action-keyword pattern (`start` / `end` / `update notes`); all timestamps shown in IST:

```apex
public without sharing class LogVisitActivityAction {
    public class Request {
        @InvocableVariable(required=true) public String visitId;
        @InvocableVariable(required=true) public String action; // start | end | update notes
        @InvocableVariable               public String visitNotes;
    }

    public class Result {
        @InvocableVariable public String visitOutput;
    }

    private static Result processRequest(Request req) {
        String action = req.action.trim().toLowerCase();
        Visit v = [SELECT Id, Status FROM Visit WHERE Id = :req.visitId LIMIT 1];

        if (String.isNotBlank(req.visitNotes)) createNote(req.visitId, req.visitNotes, 'Visit Note');

        DateTime now = DateTime.now();
        if (action == 'start') {
            if (v.Status != 'Planned') { res.visitOutput = 'Cannot start — status is ' + v.Status; return res; }
            update new Visit(Id = v.Id, Status = 'InProgress', ActualVisitStartTime = now);
            res.visitOutput = 'Visit started at ' + now.format('dd MMM yyyy, HH:mm', 'Asia/Kolkata') + ' IST.';

        } else if (action == 'end') {
            if (v.Status != 'InProgress') { res.visitOutput = 'Cannot end — status is ' + v.Status; return res; }
            update new Visit(Id = v.Id, Status = 'Completed', ActualVisitEndTime = now);
            res.visitOutput = 'Visit completed at ' + now.format('dd MMM yyyy, HH:mm', 'Asia/Kolkata') + ' IST.';
        }
        // update notes — note already created above
        return res;
    }
}
```

**`AssignLeastLoadedSurveyorAction.cls`** — seed map with 0 so surveyors with no visits are included:

```apex
@InvocableMethod(label='Get Least Loaded FieldSurveyor')
public static List<Result> execute(List<String> requests) {
    List<User> surveyors = [
        SELECT Id FROM User
        WHERE  IsActive = true AND Profile.Name = 'FieldSurveyor'
    ];
    List<AggregateResult> counts = [
        SELECT VisitorId, COUNT(Id) visitCount
        FROM   Visit
        WHERE  VisitorId IN :surveyorIds
          AND  Status IN ('Planned', 'In Progress')
        GROUP BY VisitorId
    ];
    // Seed every surveyor with 0 so unassigned surveyors are always candidates
    Map<Id, Integer> countMap = new Map<Id, Integer>();
    for (Id uid : surveyorIds) countMap.put(uid, 0);
    for (AggregateResult ar : counts)
        countMap.put((Id) ar.get('VisitorId'), (Integer) ar.get('visitCount'));

    // Pick the minimum-load surveyor
    Id bestUser = null; Integer minLoad = 999999;
    for (Id uid : countMap.keySet()) {
        if (countMap.get(uid) < minLoad) { minLoad = countMap.get(uid); bestUser = uid; }
    }
    res.userId = bestUser;
}
```

---

## 7. LWC Components

### 7.1 `storeExpansionDashboard`
**Type:** App Page component (main intelligence dashboard)  
**Purpose:** Full-featured retail expansion intelligence panel

**Features:**
- Filter bar: Retail Store Group combobox + Retail Store text search
- KPI tiles: Total Sites, Avg Demand Score, Avg Annual Revenue, Avg Payback Period
- Sites table: ranked proposed stores with demand score progress bar, Map + Details actions
- Field Visit Activity section: paginated visit tiles with urgency badges (Overdue / Due Soon) and per-visit notification bell
- Visit filter: inline combobox (All / Overdue / Due Soon / Planned / InProgress / Completed)
- Visit summary pills: Completed / In Progress / Planned count
- Geospatial map: `lightning-map` with site markers, cluster toggle, selection mode
- Visit notifications: global bell (bulk) + per-visit bell (single) via `VisitNotificationService`

**Key Properties:** `selectedGroup`, `searchTerm`, `visitStatusFilter`, `expandedRowId`, `clusterMode`  
**Apex:** `StoreExpansionController.getProposedSites`, `getSitesForDashboard`, `getStoreEvaluation`, `getRecentFieldVisits`, `sendVisitNotifications`, `sendSingleVisitNotification`

---

### 7.2 `visitDashboard`
**Type:** App Page component  
**Purpose:** Personal visit dashboard for the logged-in surveyor

**Features:**
- Header bar with visit counter (X of Y visits)
- Stats bar: In Progress (yellow) / Planned (blue) / Completed (green) tiles
- Left panel (50%): paginated `visitDashboardCard` with pinned prev/next nav
- Right panel (50%): `lightning-map` showing current visit site pin
- Visits sorted: InProgress → Planned → Completed, then by `plannedStart`

**Apex:** `VisitDashboardController.getUpcomingVisits`

---

### 7.3 `visitDashboardCard`
**Type:** Child of `visitDashboard`  
**Purpose:** Compact visit card for the dashboard — shows location hierarchy, status, schedule, Directions button

**Props:** `@api visit` (VisitDashboardDTO)  
**Key getters:** `mapsUrl` (client-side Google Maps URL from lat/lng), `statusBadgeClass`, schedule display fields

---

### 7.4 `visitCard`
**Type:** Agentforce output component + child of `visitList`  
**Purpose:** Rich visit detail card with full location breadcrumb (with navigation links), schedule, field notes

**Features:**
- `slot="title"` — "Visit Details" + inline Directions button
- Location 3-column grid: Group (link) | Store (link) | Site (link)
- Info row: Status badge | Priority | Assigned Surveyor | View Visit button
- Schedule: Planned and Actual side-by-side, start/end stacked
- Field Notes: paginated note cards (prev/next)

**Props:** `@api visit` (VisitDTO)  
**Navigation:** `NavigationMixin` for group/store/site record pages + View Visit

---

### 7.5 `visitList`
**Type:** Agentforce Lightning Type renderer (`lightning__AgentforceOutput`)  
**Purpose:** Paginates multiple visit cards in the agent chat output

**Features:**
- Stats bar: Planned / In Progress / Completed tiles
- Prev/Next paginator
- Renders `c-visit-card` for current visit

**Props:** `@api value` (VisitResponseDTO — JSON-stringified by Lightning Type)  
**Lightning Type:** `Visit_Response`

---

### 7.6 `myVisitDetails`
**Type:** Agentforce Lightning Type renderer (`lightning__AgentforceOutput`)  
**Purpose:** "My Visits" output card — same structure as visitList but branded for personal visits

**Features:**
- Header: user icon + "My Visits" + count badge
- Stats bar: Planned / In Progress / Completed / Cancelled (if > 0) tiles
- Paginated `c-my-visit-card`
- Empty state with icon

**Props:** `@api value` (VisitResponseDTO)  
**Lightning Type:** `My_Visits_Response`

---

### 7.7 `myVisitCard`
**Type:** Child of `myVisitDetails`  
**Purpose:** Read-only visit detail card for Agentforce context (no navigation links)

**Features:**
- Header: title + Directions button
- Location 3-column grid: Group | Store | Site — **plain text only, no hyperlinks**
- Info row: Status badge | Priority | Assigned Surveyor | **View Visit button** (NavigationMixin)
- Planned and Actual schedule side-by-side
- Field Notes with pagination

**Props:** `@api visit` (VisitDTO)

---

### 7.8 `siteEvaluationCard`
**Type:** Agentforce output component  
**Purpose:** Renders a `SiteEvaluationDTO` — ROI metrics, competition analysis, proposed site map

---

### 7.9 `siteDetailPanel`
**Type:** Expandable detail panel embedded in `storeExpansionDashboard` table rows  
**Purpose:** Shows full site financial and competition detail on row expand

---

## 8. Flows & Triggers

### 8.1 Flows

| Flow | Type | Trigger | Purpose |
|---|---|---|---|
| `Create_Visit_From_Site` | AutoLaunched | On demand | Calls `AssignLeastLoadedSurveyorAction` to find least-loaded surveyor; checks if RetailStore is linked; creates Visit assigned to that surveyor |

### 8.2 Triggers

| Trigger | Object | Events | Purpose |
|---|---|---|---|
| `SitesTrigger` | `Sites__c` | `after insert`, `after update` | On coordinate change → enqueues `ReverseGeocodeQueueable` for Geoapify reverse geocode (prevents re-queue if unchanged; guards against batch/future/queueable context) |
| `VisitTrigger` | `Visit` | — | Empty (reserved for future use) |

**`SitesTrigger.trigger`** — only enqueues when coordinates actually change; guards against recursive async contexts:

```apex
trigger SitesTrigger on Sites__c (after insert, after update) {
    List<ReverseGeocodeQueueable.SiteRequest> pending = new List<ReverseGeocodeQueueable.SiteRequest>();

    for (Sites__c site : Trigger.new) {
        if (site.Proposed_Site_Location__Latitude__s == null
            || site.Proposed_Site_Location__Longitude__s == null) { continue; }

        // On update, skip if coordinates haven't changed
        if (Trigger.isUpdate) {
            Sites__c old = Trigger.oldMap.get(site.Id);
            if (old.Proposed_Site_Location__Latitude__s  == site.Proposed_Site_Location__Latitude__s
             && old.Proposed_Site_Location__Longitude__s == site.Proposed_Site_Location__Longitude__s)
                { continue; }
        }

        pending.add(new ReverseGeocodeQueueable.SiteRequest(
            site.Id,
            site.Proposed_Site_Location__Latitude__s,
            site.Proposed_Site_Location__Longitude__s
        ));
    }

    // Do not enqueue from within an async context
    if (!pending.isEmpty()
        && !System.isQueueable() && !System.isBatch() && !System.isFuture()) {
        System.enqueueJob(new ReverseGeocodeQueueable(pending));
    }
}
```

### 8.3 Custom Metadata

| CMDT | Key Fields | Used By |
|---|---|---|
| `Expansion_Dashboard_Setting__mdt` | `Minimum_Demand_Score__c` | `StoreExpansionController` — filters proposed sites by minimum demand score threshold |
| `Geocoding_Config__mdt` | `Api_Key__c` | `ReverseGeocodeQueueable` — Geoapify API key |
| `Geocoding_Config__mdt` (instance: Geoapify) | `Api_Key__c` | Reverse geocode callouts |

---

## 9. Lightning Types (Agentforce Renderers)

Lightning Types map Apex class types to LWC components for rich output rendering in the agent chat.

| Lightning Type | DTO Class | LWC Renderer | Channels |
|---|---|---|---|
| `Visit_Response` | `VisitResponseDTO` | `c/visitList` | `lightningDesktopGenAi`, `enhancedWebChat` |
| `My_Visits_Response` | `VisitResponseDTO` | `c/myVisitDetails` | `lightningDesktopGenAi`, `enhancedWebChat` |
| `Site_Evaluation_Response` | `SiteEvaluationDTO` | `c/siteEvaluationList` | `lightningDesktopGenAi`, `enhancedWebChat` |
| `Site_List_Response` | `SiteListDTO` | *(siteList LWC)* | `lightningDesktopGenAi`, `enhancedWebChat` |
| `Location_Group_List_Response` | `RetailLocationGroupDTO` | *(locationGroupList LWC)* | `lightningDesktopGenAi`, `enhancedWebChat` |
| `Retail_Store_List_Response` | `RetailStoreListDTO` | *(retailStoreList LWC)* | `lightningDesktopGenAi`, `enhancedWebChat` |
| `Store_Summary_Response` | `StoreSummaryDTO` | *(storeSummaryCard LWC)* | `lightningDesktopGenAi`, `enhancedWebChat` |

> **Note:** LWC components used as Agentforce renderers must include `<target>lightning__AgentforceOutput</target>` in their `js-meta.xml`.

**`myVisitDetails.js-meta.xml`** — required metadata for Agentforce output renderer:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>66.0</apiVersion>
    <isExposed>true</isExposed>
    <targets>
        <target>lightning__AgentforceOutput</target>
    </targets>
</LightningComponentBundle>
```

The Lightning Type `schema.json` links the Apex DTO class to the LWC renderer. Example for `My_Visits_Response`:

```json
{
  "apexClass": "VisitResponseDTO",
  "renderers": [
    {
      "lwcComponent": "c/myVisitDetails",
      "channels": ["lightningDesktopGenAi", "enhancedWebChat"]
    }
  ]
}
```

---

## 10. Key End-to-End Data Flows

### 10.1 "Show me visits for Kondapur"

```
Agent → AgentVisitLookupAction
  Input: retailStoreName = "Kondapur"
  ↓
  VisitLookupImpl.lookupVisits()
    Step 1: Sites__c WHERE Retail_Store__r.Name LIKE '%Kondapur%' → siteIds
    Step 2: Visit WHERE ContextId IN :siteIds
    Step 3: Sites__c WHERE Id IN :contextIds (for hierarchy + coordinates)
    Step 4: ContentDocumentLink + ContentNote (up to 3 per visit)
    Step 5: Map to VisitDTO list
  ↓
  Returns: VisitResponseDTO (visits + counts)
  ↓
Agentforce: speaks summaryText + renders visitList LWC via Visit_Response Lightning Type
  ↓
visitList: stats bar + paginated c-visit-card components
```

### 10.2 "Show me my visits"

```
Agent → GetMyVisitsAction
  Input: statusFilter (optional)
  ↓
  UserInfo.getUserId() → userId (no user input needed)
  SOQL: Visit WHERE VisitorId = :userId [AND Status = :filter]
  Separate queries: Sites__c (hierarchy + coordinates), ContentNotes
  Map to VisitResponseDTO + build plain-text summary
  ↓
Two outputs:
  visitSummary → agent speaks: "You have 3 visits assigned..."
  visitResponse → My_Visits_Response Lightning Type → myVisitDetails LWC
  ↓
myVisitDetails: user icon header + stats tiles + paginated c-my-visit-card
```

### 10.3 "Start my visit" (surveyor in field)

```
Agent → LogVisitActivityAction
  Input: visitId = "0BI...", action = "start"
  ↓
  SOQL: Visit WHERE Id = :visitId
  Guard: Status must be "Planned"
  DateTime now = DateTime.now()
  update Visit: Status = "InProgress", ActualVisitStartTime = now
  ↓
  visitOutput = "Visit started at 29 Apr 2026, 12:30 IST. Status set to In Progress."
```

### 10.4 Data Cloud Sync (Daily Scheduled)

```
DataCloudSyncScheduler.execute()
  ↓
FootfallDataSyncImpl.executeSync()
  ↓
  ConnectApi.CdpQuery.queryAnsiSqlV2(DemandScoreFinal__cio)
  ConnectApi.CdpQuery.queryAnsiSqlV2(POS_Metrics__cio)
  ConnectApi.CdpQuery.queryAnsiSqlV2(Competition_Metrics__cio)
  ↓
  Match RetailStore records by UniqueId__c
  Upsert: Current_Demand_Score__c, Footfall_Index__c, Demographic_Score__c,
          EBITDA_Margin__c, Payback_Period_Years__c, Expected_Annual_Revenue__c,
          Competition_Level__c, Competition_Activity__c, etc.
```

### 10.5 New Site → Reverse Geocode

```
Sites__c record inserted/updated with new coordinates
  ↓
SitesTrigger (after insert/after update)
  → coordinates changed? → enqueue ReverseGeocodeQueueable
  ↓
ReverseGeocodeQueueable.execute()
  → GET https://api.geoapify.com/v1/geocode/reverse?lat={lat}&lon={lon}&apiKey={key}
  → Parse address components
  → update Sites__c.Site_Address__c
```

---

## 11. External Integrations

| Integration | Type | Class | Purpose |
|---|---|---|---|
| **Geoapify Reverse Geocoding** | REST API callout | `ReverseGeocodeQueueable` | Converts `Proposed_Site_Location__c` coordinates to human-readable address stored in `Site_Address__c` |
| **Einstein Prompt Templates** | LLM (internal) | `StoreSummaryController`, `StoreContextForPromptAction` | `Store_Agent_Summary` prompt template generates AI narrative for store expansion summary |
| **Salesforce Data Cloud** | `ConnectApi.CdpQuery` | `FootfallDataSyncImpl` | Queries Data Cloud CIOs via ANSI SQL for demand, POS, and competition metrics |

---

## 12. Dependency Map

```
AgentFieldAssessorAction
  └── ISiteLocator → SiteLocatorImpl
        └── RetailStore (GEOLOCATION SOQL), Visit (insert)

AgentSiteEvaluatorAction
  └── ISiteEvaluator → SiteEvaluatorImpl
        └── RetailStore, Sites__c, SiteEvaluationDTO, SiteDetailDTO

AgentVisitLookupAction
  └── IVisitLookup → VisitLookupImpl
        └── Visit, Sites__c, ContentDocumentLink, ContentNote
        └── VisitDTO, VisitNoteDTO, VisitResponseDTO

GetMyVisitsAction
  └── UserInfo.getUserId()
  └── Visit, Sites__c, ContentDocumentLink, ContentNote
  └── VisitDTO, VisitNoteDTO, VisitResponseDTO

LogVisitActivityAction
  └── Visit (query + update)
  └── ContentNote, ContentDocumentLink (via createNote())

AssignLeastLoadedSurveyorAction
  └── User (Profile.Name = 'FieldSurveyor')
  └── Visit (aggregate count)

AgentLocationGroupListAction / AgentRetailStoreListAction / AgentSiteListAction
  └── RetailLocationGroup, RetailStore, Sites__c, Visit
  └── RetailLocationGroupDTO, RetailStoreListDTO, SiteListDTO, SiteVisitDTO

StoreExpansionController
  └── RetailStore, Sites__c, Visit, Expansion_Dashboard_Setting__mdt
  └── VisitNotificationService

VisitNotificationService
  └── CustomNotificationType (Visit_Alert)
  └── Visit, Messaging.CustomNotification

FootfallDataSyncImpl
  └── ConnectApi.CdpQuery (Data Cloud)
  └── RetailStore (upsert)

SitesTrigger
  └── Sites__c
  └── ReverseGeocodeQueueable → Geoapify API

Create_Visit_From_Site (Flow)
  └── AssignLeastLoadedSurveyorAction
  └── Visit (insert)

storeExpansionDashboard (LWC)
  └── StoreExpansionController (6 methods)
  └── c-site-detail-panel

visitDashboard (LWC)
  └── VisitDashboardController
  └── c-visit-dashboard-card

visitList (LWC) ← Visit_Response Lightning Type
  └── c-visit-card

myVisitDetails (LWC) ← My_Visits_Response Lightning Type
  └── c-my-visit-card
        └── NavigationMixin (View Visit record navigation)
```

---

Feature request 
---
name: Feature Request
about: Suggest a new Agentforce action, dashboard feature, or platform capability
title: "[FEATURE] "
labels: enhancement
assignees: ''
---

## Summary
A concise description of what you want to add or improve.

## Problem It Solves
What gap or limitation does this address? Who benefits — Expansion Manager, Field Surveyor, or both?

## Proposed Solution
Describe how you think this should work. Be as specific as possible.

**If it's an Agentforce Action:**
- Action label:
- Inputs:
- Outputs (text + Lightning Type card?):
- Objects queried:

**If it's a Dashboard feature:**
- Which component: `storeExpansionDashboard` / `visitDashboard` / other
- UI description:

**If it's a Data / Sync feature:**
- Data source:
- Target object / fields:

## Alternatives Considered
Any other approaches you thought about and why you ruled them out.

## Additional Context
Screenshots, mockups, or examples that help explain the request.















Bug Report

---
name: Bug Report
about: Report a defect in an Apex action, LWC component, flow, or metadata
title: "[BUG] "
labels: bug
assignees: ''
---

## Description
A clear description of what the bug is.

## Layer Affected
- [ ] Agentforce Action (Apex)
- [ ] LWC Component
- [ ] Flow
- [ ] Lightning Type / Renderer
- [ ] Data Cloud Sync
- [ ] Trigger / Queueable
- [ ] Dashboard

## Steps to Reproduce
1. Go to '...'
2. Ask the agent '...'
3. See error

## Expected Behaviour
What you expected to happen.

## Actual Behaviour
What actually happened. Include any error messages or screenshots.

## Environment
- Salesforce API Version:
- CG Cloud version:
- Agentforce enabled: Yes / No
- Data Cloud connected: Yes / No

## Additional Context
Any other relevant details — SOQL errors, debug logs, Apex exceptions, etc.











Contributing.md


# Contributing to VyuhX

Thank you for your interest in contributing. VyuhX is a Salesforce CG Cloud + Agentforce + Data Cloud project — contributions should follow Salesforce platform conventions.

---

## Before You Start

- Read [TECHNICAL_DESIGN.md](./TECHNICAL_DESIGN.md) to understand the architecture
- Make sure you have a Salesforce scratch org or sandbox with CG Cloud and Agentforce enabled
- Salesforce CLI (`sf` v2+) must be installed and authenticated

---

## What You Can Contribute

- Bug fixes in Apex actions, LWC components, or flows
- New Agentforce actions following the existing `Request / Result / @InvocableMethod` pattern
- LWC improvements to the expansion dashboard or visit card components
- Additional Lightning Type renderers
- Test class coverage (Apex unit tests)
- Documentation improvements

---

## Development Setup

```bash
# Clone the repo
git clone https://github.com/your-org/vyuhx.git
cd vyuhx

# Authenticate to your org
sf org login web --alias vyuhx-dev

# Deploy source
sf project deploy start --source-dir force-app --target-org vyuhx-dev
```

---

## Contribution Guidelines

### Apex

- Follow the `without sharing` pattern for all Agentforce action classes
- All agent actions must use the `Request` / `Result` inner class pattern with `@InvocableVariable`
- Query logic must live in a service implementation class, not directly inside the action
- Never hardcode API keys, org IDs, or credentials — use Custom Metadata
- All SOQL inputs from external sources must use bind variables (`:variable`), not string concatenation

### LWC

- Agentforce renderer components must declare `<target>lightning__AgentforceOutput</target>` in `js-meta.xml`
- Maps URLs must be built client-side from `latitude` / `longitude` fields — no server roundtrip
- Use `NavigationMixin` for all record navigation links
- Keep manager-facing and surveyor-facing card variants separate (`visitCard` vs `myVisitCard`)

### Flows

- AutoLaunched flows that update Visit records must use `SystemModeWithoutSharing`
- Add a decision node guard before any field that could be null-overwritten on a second call

### General

- One feature or fix per pull request
- Keep PRs focused — do not mix unrelated changes
- Test your changes in a scratch org before submitting

---

## Pull Request Process

1. Fork the repository and create a branch: `git checkout -b feature/your-feature-name`
2. Make your changes
3. Deploy and test in a scratch org
4. Submit a pull request with a clear description of what changed and why
5. Link any related issues in the PR description

---

## Reporting Issues

Use the GitHub Issue templates:
- **Bug Report** — for defects in Apex, LWC, flows, or metadata
- **Feature Request** — for new Agentforce actions, dashboard enhancements, or capability ideas

---

## Code of Conduct

Be respectful and constructive. This is a collaborative project — all contributors are expected to maintain a professional and inclusive environment.
