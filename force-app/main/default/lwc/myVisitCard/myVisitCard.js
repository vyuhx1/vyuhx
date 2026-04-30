import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class MyVisitCard extends NavigationMixin(LightningElement) {
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

    // ── Location ───────────────────────────────────────────────
    get groupDisplay()       { return this.visit?.groupName    || '—'; }
    get retailStoreDisplay() { return this.visit?.retailStore  || '—'; }
    get siteDisplay()        { return this.visit?.siteName     || '—'; }

    // ── Directions ─────────────────────────────────────────────
    get mapsUrl() {
        const lat = this.visit?.latitude;
        const lng = this.visit?.longitude;
        if (lat != null && lng != null) {
            return `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`;
        }
        return null;
    }

    // ── Status ─────────────────────────────────────────────────
    get statusLabel() {
        const s = this.visit?.status || '';
        if (s === 'InProgress') return 'In Progress';
        return s || 'Unknown';
    }

    get statusBadgeClass() {
        const map = {
            'Completed':  'mvc-status-badge mvc-status-completed',
            'InProgress': 'mvc-status-badge mvc-status-inprogress',
            'Cancelled':  'mvc-status-badge mvc-status-cancelled',
            'Planned':    'mvc-status-badge mvc-status-planned'
        };
        return map[this.visit?.status] || 'mvc-status-badge mvc-status-planned';
    }

    // ── Schedule ───────────────────────────────────────────────
    get priorityDisplay()     { return this.visit?.priority    || '—'; }
    get plannedStartDisplay() { return this.visit?.plannedStart || '—'; }
    get plannedEndDisplay()   { return this.visit?.plannedEnd   || '—'; }
    get actualStartDisplay()  { return this.visit?.actualStart  || '—'; }
    get actualEndDisplay()    { return this.visit?.actualEnd    || '—'; }

    get hasActualTimes() {
        return !!(this.visit?.actualStart || this.visit?.actualEnd);
    }

    // ── Notes ──────────────────────────────────────────────────
    get hasNotes()         { return (this.visit?.notes?.length ?? 0) > 0; }
    get hasMultipleNotes() { return (this.visit?.notes?.length ?? 0) > 1; }
    get currentNote()      { return this.visit?.notes?.[this._noteIdx] || {}; }
    get isFirstNote()      { return this._noteIdx === 0; }
    get isLastNote()       { return this._noteIdx >= (this.visit?.notes?.length ?? 1) - 1; }
    get noteNavDisplay()   { return `${this._noteIdx + 1} of ${this.visit?.notes?.length ?? 0}`; }

    handlePrevNote() {
        if (this._noteIdx > 0) this._noteIdx -= 1;
    }

    handleNextNote() {
        if (this._noteIdx < (this.visit?.notes?.length ?? 1) - 1) this._noteIdx += 1;
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
}