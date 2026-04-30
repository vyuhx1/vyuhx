import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class RetailStoreCard extends NavigationMixin(LightningElement) {
    @api store;
    @track siteIndex = 0;

    // ── Site navigation ───────────────────────────────────────────────
    get sites() {
        return this.store?.sites || [];
    }

    get hasSites() {
        return this.sites.length > 0;
    }

    get currentSite() {
        return this.sites[this.siteIndex];
    }

    get siteCount() {
        return this.sites.length;
    }

    get sitePosLabel() {
        return `Site ${this.siteIndex + 1} of ${this.siteCount}`;
    }

    get isSitePreviousDisabled() {
        return this.siteIndex === 0;
    }

    get isSiteNextDisabled() {
        return this.siteIndex >= this.sites.length - 1;
    }

    get currentSiteVisits() {
        return this.currentSite?.visits || [];
    }

    get hasCurrentSiteVisits() {
        return this.currentSiteVisits.length > 0;
    }

    handlePreviousSite() {
        if (!this.isSitePreviousDisabled) this.siteIndex -= 1;
    }

    handleNextSite() {
        if (!this.isSiteNextDisabled) this.siteIndex += 1;
    }

    handleViewSite(event) {
        const siteId = event.currentTarget.dataset.siteid;
        if (!siteId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: siteId,
                objectApiName: 'Sites__c',
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

    // ── Store display ─────────────────────────────────────────────────
    get locationBadge() {
        const parts = [this.store?.subArea, this.store?.city].filter(Boolean);
        return parts.join(', ');
    }

    get hasRetailLocationGroup() {
        return !!this.store?.retailLocationGroupId;
    }

    get demandProgress() {
        const val = Number(this.store?.currentDemandScore) || 0;
        return Math.min(Math.max(val, 0), 100);
    }

    get demandScoreFormatted() {
        return Number(this.store?.currentDemandScore || 0).toFixed(2);
    }

    get footfallIndexFormatted() {
        return Number(this.store?.footfallIndex || 0).toFixed(2) + '%';
    }

    get demographicScoreFormatted() {
        return Number(this.store?.demographicScore || 0).toFixed(2) + '%';
    }

    get ebitdaMarginFormatted() {
        return Number(this.store?.ebitdaMargin || 0).toFixed(2);
    }

    get paybackPeriodFormatted() {
        return Number(this.store?.paybackPeriodYears || 0).toFixed(2);
    }

    handleViewRecord() {
        if (!this.store?.storeId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.store.storeId,
                actionName: 'view'
            }
        });
    }
}