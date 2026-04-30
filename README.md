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
