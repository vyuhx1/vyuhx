import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProposedSites from '@salesforce/apex/StoreExpansionController.getProposedSites';
import getRecentFieldVisits from '@salesforce/apex/StoreExpansionController.getRecentFieldVisits';
import getSitesForDashboard from '@salesforce/apex/StoreExpansionController.getSitesForDashboard';
import getStoreEvaluation from '@salesforce/apex/StoreExpansionController.getStoreEvaluation';
import sendVisitNotifications from '@salesforce/apex/StoreExpansionController.sendVisitNotifications';
import sendSingleVisitNotification from '@salesforce/apex/StoreExpansionController.sendSingleVisitNotification';

const TOP_N_STEP = 5;

export default class StoreExpansionDashboard extends NavigationMixin(LightningElement) {
    @track allSites = [];
    @track allSiteRecords = [];
    @track allMapMarkers = [];
    @track recentVisits = [];
    @track hasMoreVisits = false;
    _visitOffset = 0;
    @track selectedGroup = '';
    @track topN = TOP_N_STEP;
    @track selectedSite = null;
    @track selectedSiteMarkers = null;
    @track searchTerm = '';
    @track expandedRowId = null;
    @track expandedSiteData = null;
    @track clusterMode = false;

    @track isSendingNotifications = false;
    @track _notifyingVisitIds = new Set();
    @track visitStatusFilter = '';

    connectedCallback() {
        this._loadVisits();
    }

    _loadVisits(append = false) {
        getRecentFieldVisits({ groupName: this.selectedGroup, storeName: this.searchTerm || null, pageOffset: this._visitOffset })
            .then(data => {
                this.hasMoreVisits = data.length > 5;
                const page = data.slice(0, 5);
                const now = new Date();
                const threeDays = 3 * 24 * 60 * 60 * 1000;
                const mapped = page.map(record => {
                    const plannedDate = record.PlannedVisitStartTime ? new Date(record.PlannedVisitStartTime) : null;
                    const isOverdue = plannedDate && plannedDate < now && (record.Status || '').toLowerCase() === 'planned';
                    const isDueSoon = plannedDate && !isOverdue && (plannedDate - now) <= threeDays && (record.Status || '').toLowerCase() === 'planned';
                    return {
                        ...record,
                        SiteName: record.Context ? record.Context.Name : 'Unknown Site',
                        visitUrl: `/lightning/r/Visit/${record.Id}/view`,
                        visitorName: record.Visitor ? record.Visitor.Name : null,
                        badgeClass: this._badgeClass(record.Status),
                        statusIcon: this._statusIcon(record.Status),
                        visitDateFormatted: plannedDate
                            ? new Intl.DateTimeFormat('en-US', { dateStyle: 'medium', timeStyle: 'short' }).format(plannedDate)
                            : 'N/A',
                        urgencyLabel: isOverdue ? 'Overdue' : (isDueSoon ? 'Due Soon' : null),
                        urgencyClass: isOverdue ? 'urgency-badge urgency-overdue' : 'urgency-badge urgency-soon'
                    };
                });
                this.recentVisits = append ? [...this.recentVisits, ...mapped] : mapped;
            })
            .catch(err => console.error('Error loading visits', err));
    }

    @wire(getProposedSites)
    wiredSites({ error, data }) {
        if (data) {
            this.allSites = data.map(record => ({
                ...record,
                ZoneName: record.RetailLocationGroup ? record.RetailLocationGroup.Name : 'N/A',
                siteUrl: `/lightning/r/RetailStore/${record.Id}/view`,
                competitionBadgeLabel: record.Competition_Level__c || '—',
                competitionBadgeClass: this._competitionClass(record.Competition_Level__c)
            }));
            this._rebuildMarkers();
        } else if (error) {
            console.error('Error loading sites', error);
        }
    }

    @wire(getSitesForDashboard)
    wiredSiteRecords({ error, data }) {
        if (data) {
            this.allSiteRecords = data;
            this._rebuildMarkers();
        } else if (error) {
            console.error('Error loading site records', error);
        }
    }

    // ── Filters ────────────────────────────────────────────────
    get groupOptions() {
        const groups = [...new Set(
            this.allSites.map(s => s.ZoneName).filter(g => g && g !== 'N/A')
        )].sort();
        return [{ label: 'All Groups', value: '' }, ...groups.map(g => ({ label: g, value: g }))];
    }

    get filteredSites() {
        let sites = this.selectedGroup
            ? this.allSites.filter(s => s.ZoneName === this.selectedGroup)
            : this.allSites;
        if (this.searchTerm) {
            const term = this.searchTerm.toLowerCase();
            sites = sites.filter(s => s.Name.toLowerCase().includes(term));
        }
        return sites;
    }

    get displayedSites() {
        return this.filteredSites.slice(0, this.topN).map(s => ({
            ...s,
            demandProgress: Math.min(Math.max(Number(s.Current_Demand_Score__c) || 0, 0), 100),
            demandScoreLabel: Number(s.Current_Demand_Score__c || 0).toFixed(1),
            groupUrl: s.RetailLocationGroup ? `/lightning/r/RetailLocationGroup/${s.RetailLocationGroup.Id}/view` : null,
            isExpanded: s.Id === this.expandedRowId,
            expandBtnLabel: s.Id === this.expandedRowId ? 'Collapse' : 'Details',
            evaluationData: s.Id === this.expandedRowId ? this.expandedSiteData : null
        }));
    }

    get totalCount() {
        return this.filteredSites.length;
    }

    get hasMore() {
        return this.topN < this.filteredSites.length;
    }

    get summaryLabel() {
        return `Showing ${Math.min(this.topN, this.totalCount)} of ${this.totalCount}`;
    }

    // ── KPI Tiles ──────────────────────────────────────────────
    get kpiTotalSites() {
        return this.filteredSites.length;
    }

    get kpiAvgScore() {
        if (!this.filteredSites.length) return '—';
        const sum = this.filteredSites.reduce((a, s) => a + (Number(s.Current_Demand_Score__c) || 0), 0);
        return (sum / this.filteredSites.length).toFixed(1);
    }

    get kpiAvgRevenue() {
        if (!this.filteredSites.length) return '—';
        const sum = this.filteredSites.reduce((a, s) => a + (Number(s.Expected_Annual_Revenue__c) || 0), 0);
        const avg = sum / this.filteredSites.length;
        return avg >= 100000
            ? `₹${(avg / 100000).toFixed(1)}L`
            : `₹${Math.round(avg).toLocaleString('en-IN')}`;
    }

    get kpiAvgPayback() {
        if (!this.filteredSites.length) return '—';
        const valid = this.filteredSites.filter(s => s.Payback_Period_Years__c != null);
        if (!valid.length) return '—';
        const sum = valid.reduce((a, s) => a + Number(s.Payback_Period_Years__c), 0);
        return `${(sum / valid.length).toFixed(1)} yrs`;
    }

    // ── Map ────────────────────────────────────────────────────
    get mapMarkers() {
        return this.selectedSiteMarkers || this.allMapMarkers;
    }

    get isSelectionMode() {
        return !!this.selectedSite;
    }

    get selectedSiteName() {
        return this.selectedSite ? this.selectedSite.Name : null;
    }

    get mapListView() {
        return (this.selectedGroup || this.selectedSite) ? 'visible' : 'hidden';
    }

    get clusterLabel() {
        return this.clusterMode ? 'Show All Pins' : 'Reduce Pins';
    }

    get clusterIcon() {
        return this.clusterMode ? 'utility:multi_layer_schema' : 'utility:cluster';
    }

    get hasMapMarkers() {
        return this.mapMarkers.length > 0;
    }

    // ── Visit summary pills ───────────────────────────────────
    get visitCompleted() {
        return this.recentVisits.filter(v => (v.Status || '').toLowerCase() === 'completed').length;
    }
    get visitInProgress() {
        return this.recentVisits.filter(v => (v.Status || '').toLowerCase().includes('progress')).length;
    }
    get visitPlanned() {
        return this.recentVisits.filter(v => (v.Status || '').toLowerCase() === 'planned').length;
    }
    get visitCancelled() {
        return this.recentVisits.filter(v => (v.Status || '').toLowerCase() === 'cancelled').length;
    }

    get hasVisits() {
        return this.recentVisits.length > 0;
    }

    get visitFilterOptions() {
        return [
            { label: 'All Visits',   value: '' },
            { label: 'Overdue',      value: 'overdue' },
            { label: 'Due Soon',     value: 'duesoon' },
            { label: 'Planned',      value: 'planned' },
            { label: 'In Progress',  value: 'inprogress' },
            { label: 'Completed',    value: 'completed' },
        ];
    }

    get filteredVisits() {
        if (!this.visitStatusFilter) return this.recentVisits;
        return this.recentVisits.filter(v => {
            if (this.visitStatusFilter === 'overdue')    return v.urgencyLabel === 'Overdue';
            if (this.visitStatusFilter === 'duesoon')    return v.urgencyLabel === 'Due Soon';
            const status = (v.Status || '').toLowerCase();
            if (this.visitStatusFilter === 'planned')    return status === 'planned';
            if (this.visitStatusFilter === 'inprogress') return status.includes('progress');
            if (this.visitStatusFilter === 'completed')  return status === 'completed';
            return true;
        });
    }

    get hasFilteredVisits() {
        return this.filteredVisits.length > 0;
    }

    // ── Handlers ───────────────────────────────────────────────
    handleVisitFilterChange(event) {
        this.visitStatusFilter = event.detail.value;
    }

    handleNotifyVisit(event) {
        const visitId = event.currentTarget.dataset.id;
        this._notifyingVisitIds = new Set([...this._notifyingVisitIds, visitId]);
        // force re-render
        this.recentVisits = this.recentVisits.map(v =>
            v.Id === visitId ? { ...v, _notifying: true } : v
        );
        sendSingleVisitNotification({ visitId })
            .then(() => {
                this.recentVisits = this.recentVisits.map(v =>
                    v.Id === visitId ? { ...v, _notifying: false, _notified: true } : v
                );
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Notification Sent',
                    message: 'The assigned surveyor has been notified.',
                    variant: 'success'
                }));
            })
            .catch(err => {
                this.recentVisits = this.recentVisits.map(v =>
                    v.Id === visitId ? { ...v, _notifying: false } : v
                );
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: err?.body?.message || 'Failed to send notification.',
                    variant: 'error'
                }));
            });
    }

    handleSendNotifications() {
        this.isSendingNotifications = true;
        sendVisitNotifications()
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Notifications Sent',
                    message: 'Overdue and due-soon visit alerts have been sent to all assigned surveyors.',
                    variant: 'success'
                }));
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error Sending Notifications',
                    message: err?.body?.message || 'An unexpected error occurred.',
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isSendingNotifications = false;
            });
    }

    handleGroupChange(event) {
        this.selectedGroup = event.detail.value;
        this.topN = TOP_N_STEP;
        this.selectedSite = null;
        this.selectedSiteMarkers = null;
        this.expandedRowId = null;
        this.expandedSiteData = null;
        this._visitOffset = 0;
        this.recentVisits = [];
        this.hasMoreVisits = false;
        this._loadVisits();
        this._rebuildMarkers();
    }

    handleSearchChange(event) {
        this.searchTerm = event.detail.value;
        this.topN = TOP_N_STEP;
        this.selectedSite = null;
        this.selectedSiteMarkers = null;
        this._visitOffset = 0;
        this.recentVisits = [];
        this.hasMoreVisits = false;
        this._loadVisits();
        this._rebuildMarkers();
    }

    handleClearSelection() {
        this.selectedSite = null;
        this.selectedSiteMarkers = null;
    }

    handleLoadMore() {
        this.topN += TOP_N_STEP;
    }

    handleLoadMoreVisits() {
        this._visitOffset += 5;
        this._loadVisits(true);
    }

    handleRowAction(event) {
        const rowId = event.currentTarget.dataset.id;
        const row = this.allSites.find(s => s.Id === rowId);
        if (!row) return;
        this.selectedSite = row;
        const sites = this.allSiteRecords.filter(s => s.Retail_Store__c === rowId);
        const markers = [];
        sites.slice(0, 3).forEach((s, idx) => {
            const coords = this._resolveLatLon(s);
            if (coords) {
                markers.push({
                    location: { Latitude: coords.lat, Longitude: coords.lon },
                    title: s.Name,
                    description: `Competition: ${s.Competition_Level__c ?? 'N/A'} | Activity: ${s.Competition_Activity__c ?? 'N/A'} | Confidence: ${s.Competition_Confidence__c ?? 'N/A'} | Impact: ${s.Competition_Impact__c ?? 'N/A'}`
                });
            }
        });
        this.selectedSiteMarkers = markers.length ? markers : null;
    }

    handleToggleExpand(event) {
        const rowId = event.currentTarget.dataset.id;
        if (this.expandedRowId === rowId) {
            this.expandedRowId = null;
            this.expandedSiteData = null;
            return;
        }
        this.expandedRowId = rowId;
        this.expandedSiteData = null;
        getStoreEvaluation({ storeId: rowId })
            .then(result => {
                if (this.expandedRowId === rowId) {
                    this.expandedSiteData = result;
                }
            })
            .catch(err => console.error('Error loading store evaluation', err));
    }

    handleClusterToggle() {
        this.clusterMode = !this.clusterMode;
        this._rebuildMarkers();
    }

    // ── Helpers ────────────────────────────────────────────────
    _rebuildMarkers() {
        if (!this.allSites.length || !this.allSiteRecords.length) return;
        let visibleStores = this.selectedGroup
            ? this.allSites.filter(s => s.ZoneName === this.selectedGroup)
            : this.allSites;
        if (this.searchTerm) {
            const term = this.searchTerm.toLowerCase();
            visibleStores = visibleStores.filter(s => s.Name.toLowerCase().includes(term));
        }
        const visibleStoreIds = new Set(visibleStores.map(s => s.Id));
        const storeMap = new Map(visibleStores.map(s => [s.Id, s]));
        const countPerStore = {};
        const maxPerStore = this.clusterMode ? 1 : 3;
        const markers = [];
        this.allSiteRecords
            .filter(s => visibleStoreIds.has(s.Retail_Store__c))
            .forEach(s => {
                const count = countPerStore[s.Retail_Store__c] || 0;
                if (count < maxPerStore) {
                    const coords = this._resolveLatLon(s);
                    if (coords) {
                        const store = storeMap.get(s.Retail_Store__c);
                        markers.push({
                            location: { Latitude: coords.lat, Longitude: coords.lon },
                            title: s.Name,
                            description: `Zone: ${store ? store.ZoneName : 'N/A'} | Competition: ${s.Competition_Level__c ?? 'N/A'} | Confidence: ${s.Competition_Confidence__c ?? 'N/A'}`
                        });
                        countPerStore[s.Retail_Store__c] = count + 1;
                    }
                }
            });
        this.allMapMarkers = markers;
    }

    _resolveLatLon(s) {
        const lat = s.Proposed_Site_Location__Latitude__s;
        const lon = s.Proposed_Site_Location__Longitude__s;
        if (lat == null || lon == null) return null;
        return { lat: Number(lat), lon: Number(lon) };
    }

    _competitionClass(level) {
        const l = (level || '').toLowerCase();
        if (l === 'low') return 'comp-badge comp-low';
        if (l === 'high') return 'comp-badge comp-high';
        return 'comp-badge comp-medium';
    }

    _badgeClass(status) {
        const s = (status || '').toLowerCase();
        if (s === 'completed') return 'status-badge status-completed';
        if (s.includes('progress')) return 'status-badge status-in-progress';
        if (s === 'cancelled') return 'status-badge status-cancelled';
        return 'status-badge status-planned';
    }

    _statusIcon(status) {
        const s = (status || '').toLowerCase();
        if (s === 'completed') return 'utility:check';
        if (s.includes('progress')) return 'utility:spinner';
        if (s === 'cancelled') return 'utility:close';
        return 'utility:clock';
    }
}