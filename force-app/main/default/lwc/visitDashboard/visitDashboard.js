import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getUpcomingVisits from '@salesforce/apex/VisitDashboardController.getUpcomingVisits';

export default class VisitDashboard extends NavigationMixin(LightningElement) {
    @track _visits = [];
    @track _idx = 0;
    @track isLoading = true;
    @track hasError = false;

    @wire(getUpcomingVisits)
    wiredVisits({ error, data }) {
        this.isLoading = false;
        if (data) {
            // Sort: InProgress → Planned → Completed → everything else
            const order = { 'InProgress': 0, 'Planned': 1, 'Completed': 2 };
            this._visits = [...data].sort((a, b) => {
                const oa = order[a.status] ?? 3;
                const ob = order[b.status] ?? 3;
                if (oa !== ob) return oa - ob;
                // secondary: plannedStart ascending
                return (a.plannedStart || '') < (b.plannedStart || '') ? -1 : 1;
            });
            this._idx    = 0;
            this.hasError = false;
        } else if (error) {
            this.hasError = true;
            this._visits  = [];
            const msg = error?.body?.message || error?.message || JSON.stringify(error);
            console.error('VisitDashboard error:', msg);
        }
    }

    get hasVisits() {
        return this._visits.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.hasError && this._visits.length === 0;
    }

    get totalVisits() {
        return this._visits.length;
    }

    get plannedCount() {
        return this._visits.filter(v => v.status === 'Planned').length;
    }

    get inProgressCount() {
        return this._visits.filter(v => v.status === 'InProgress').length;
    }

    get completedCount() {
        return this._visits.filter(v => v.status === 'Completed').length;
    }

    get currentVisit() {
        return this._visits[this._idx] || null;
    }

    get currentIndexDisplay() {
        return this._visits.length > 0 ? this._idx + 1 : 0;
    }

    get isFirst() {
        return this._idx === 0;
    }

    get isLast() {
        return this._idx >= this._visits.length - 1;
    }

    get mapMarkers() {
        const v = this.currentVisit;
        if (!v || v.latitude == null || v.longitude == null) return [];
        return [{
            location: { Latitude: v.latitude, Longitude: v.longitude },
            title: v.siteName || 'Visit Site',
            description: `${v.retailStore || ''} ${v.groupName ? '· ' + v.groupName : ''}`.trim()
        }];
    }

    get hasMapPin() {
        return this.mapMarkers.length > 0;
    }

    handlePrev() {
        if (this._idx > 0) this._idx -= 1;
    }

    handleNext() {
        if (this._idx < this._visits.length - 1) this._idx += 1;
    }
}