import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class SiteCard extends NavigationMixin(LightningElement) {
    @api site;

    get locationBadge() {
        const parts = [this.site?.retailStoreSubArea, this.site?.retailStoreCity].filter(Boolean);
        return parts.join(', ');
    }

    get statusVariant() {
        const s = (this.site?.status || '').toLowerCase();
        if (s === 'active') return 'success';
        if (s === 'inactive' || s === 'closed') return 'error';
        return 'warning';
    }

    get competitionLevelFormatted() {
        return this.site?.competitionLevel != null ? Number(this.site.competitionLevel).toFixed(2) : 'N/A';
    }

    get competitionActivityFormatted() {
        return this.site?.competitionActivity != null ? Number(this.site.competitionActivity).toFixed(2) : 'N/A';
    }

    get competitionConfidenceFormatted() {
        return this.site?.competitionConfidence != null ? Number(this.site.competitionConfidence).toFixed(2) : 'N/A';
    }

    get competitionImpactFormatted() {
        return this.site?.competitionImpact != null ? Number(this.site.competitionImpact).toFixed(2) : 'N/A';
    }

    get distanceKmFormatted() {
        return this.site?.distanceKm != null ? Number(this.site.distanceKm).toFixed(2) : 'N/A';
    }

    get hasVisits() {
        return this.site?.visits?.length > 0;
    }

    get visitCount() {
        return this.site?.visits?.length || 0;
    }

    get hasLocation() {
        return this.site?.latitude != null && this.site?.longitude != null;
    }

    get mapMarkers() {
        if (!this.hasLocation) return [];
        return [{
            location: {
                Latitude: Number(this.site.latitude),
                Longitude: Number(this.site.longitude)
            },
            title: this.site.siteName,
            description: this.site.retailStoreName || ''
        }];
    }

    handleViewRecord() {
        if (!this.site?.siteId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.site.siteId,
                objectApiName: 'Sites__c',
                actionName: 'view'
            }
        });
    }

    handleViewStore() {
        if (!this.site?.retailStoreId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.site.retailStoreId,
                objectApiName: 'RetailStore',
                actionName: 'view'
            }
        });
    }

    handleViewVisit(event) {
        const visitId = event.currentTarget.dataset.visitid;
        if (!visitId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: visitId,
                objectApiName: 'Visit',
                actionName: 'view'
            }
        });
    }
}