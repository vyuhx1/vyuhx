import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class VisitCard extends NavigationMixin(LightningElement) {
    @track _visit;
    @track _noteIdx = 0;

    @api
    get visit() {
        return this._visit;
    }
    set visit(val) {
        this._visit = val;
        this._noteIdx = 0;
    }

    get cardTitle() {
        return this.visit?.siteName || 'Visit';
    }

    get mapsUrl() {
        const lat = this.visit?.latitude;
        const lng = this.visit?.longitude;
        if (lat != null && lng != null) {
            return `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`;
        }
        return null;
    }

    get retailStoreDisplay() {
        return this.visit?.retailStore || '—';
    }

    get statusLabel() {
        const s = this.visit?.status || '';
        if (s === 'InProgress') return 'In Progress';
        return s || 'Unknown';
    }

    get statusVariant() {
        switch (this.visit?.status) {
            case 'Completed':  return 'success';
            case 'InProgress': return 'warning';
            case 'Cancelled':  return 'error';
            default:           return '';   // neutral for Planned
        }
    }

    get hasActualTimes() {
        return !!(this.visit?.actualStart || this.visit?.actualEnd);
    }

    get hasNotes() {
        return (this.visit?.notes?.length ?? 0) > 0;
    }

    get hasMultipleNotes() {
        return (this.visit?.notes?.length ?? 0) > 1;
    }

    get currentNote() {
        return this.visit?.notes?.[this._noteIdx] || {};
    }

    get noteNavDisplay() {
        return `${this._noteIdx + 1} of ${this.visit?.notes?.length ?? 0}`;
    }

    get isFirstNote() {
        return this._noteIdx === 0;
    }

    get isLastNote() {
        return this._noteIdx >= (this.visit?.notes?.length ?? 1) - 1;
    }

    get plannedStartDisplay() {
        return this.visit?.plannedStart || '—';
    }

    get plannedEndDisplay() {
        return this.visit?.plannedEnd || '—';
    }

    get actualStartDisplay() {
        return this.visit?.actualStart || '—';
    }

    get actualEndDisplay() {
        return this.visit?.actualEnd || '—';
    }

    get priorityDisplay() {
        return this.visit?.priority || '—';
    }

    handleGroupNavigation(event) {
        event.preventDefault();
        // RetailLocationGroup has no standard record page — navigate to RetailStore list filtered by group if needed
        // For now, no-op or extend as required
    }

    handleRetailStoreNavigation(event) {
        event.preventDefault();
        if (!this.visit?.siteId) return;
        // Navigate to the RetailStore linked via the site
        // We don't store retailStoreId directly — navigate to the site's parent store via site record for now
    }

    handleStoreNavigation(event) {
        event.preventDefault();
        if (!this.visit?.siteId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.visit.siteId,
                objectApiName: 'RetailStore',
                actionName: 'view'
            }
        });
    }

    handleViewRecord() {
        if (!this.visit?.visitId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.visit.visitId,
                objectApiName: 'Visit',
                actionName: 'view'
            }
        });
    }

    handlePrevNote() {
        if (this._noteIdx > 0) this._noteIdx -= 1;
    }

    handleNextNote() {
        if (this._noteIdx < (this.visit?.notes?.length ?? 1) - 1) {
            this._noteIdx += 1;
        }
    }
}