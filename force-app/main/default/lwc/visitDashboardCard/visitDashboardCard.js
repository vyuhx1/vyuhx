import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class VisitDashboardCard extends NavigationMixin(LightningElement) {
    @api visit;

    get statusLabel() {
        const s = this.visit?.status || '';
        if (s === 'InProgress') return 'In Progress';
        return s || 'Unknown';
    }

    get statusClass() {
        switch (this.visit?.status) {
            case 'Completed':  return 'status-badge status-completed';
            case 'InProgress': return 'status-badge status-inprogress';
            case 'Cancelled':  return 'status-badge status-cancelled';
            default:           return 'status-badge status-planned';
        }
    }

    get priorityDisplay() {
        return this.visit?.priority || '—';
    }

    get mapsUrl() {
        const lat = this.visit?.latitude;
        const lng = this.visit?.longitude;
        if (lat != null && lng != null) {
            return `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`;
        }
        return null;
    }

    get hasActualTimes() {
        return !!(this.visit?.actualStart || this.visit?.actualEnd);
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