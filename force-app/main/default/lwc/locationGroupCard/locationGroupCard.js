import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class LocationGroupCard extends NavigationMixin(LightningElement) {
    @api group;
    @track storeIndex = 0;
    @track siteIndex = 0;

    // ── Store navigation ──────────────────────────────────
    get stores() {
        return this.group?.stores || [];
    }

    get hasStores() {
        return this.stores.length > 0;
    }

    get currentStore() {
        return this.stores[this.storeIndex];
    }

    get storeCount() {
        return this.stores.length;
    }

    get storePosLabel() {
        return `Store ${this.storeIndex + 1} of ${this.storeCount}`;
    }

    get isStorePreviousDisabled() {
        return this.storeIndex === 0;
    }

    get isStoreNextDisabled() {
        return this.storeIndex >= this.stores.length - 1;
    }

    handlePreviousStore() {
        if (!this.isStorePreviousDisabled) {
            this.storeIndex -= 1;
            this.siteIndex = 0;
        }
    }

    handleNextStore() {
        if (!this.isStoreNextDisabled) {
            this.storeIndex += 1;
            this.siteIndex = 0;
        }
    }

    // ── Site navigation ───────────────────────────────────
    get currentStoreSites() {
        return this.currentStore?.sites || [];
    }

    get hasCurrentStoreSites() {
        return this.currentStoreSites.length > 0;
    }

    get currentSite() {
        return this.currentStoreSites[this.siteIndex];
    }

    get siteCount() {
        return this.currentStoreSites.length;
    }

    get sitePosLabel() {
        return `Site ${this.siteIndex + 1} of ${this.siteCount}`;
    }

    get isSitePreviousDisabled() {
        return this.siteIndex === 0;
    }

    get isSiteNextDisabled() {
        return this.siteIndex >= this.currentStoreSites.length - 1;
    }

    get currentSiteVisits() {
        return this.currentSite?.visits || [];
    }

    get hasCurrentSiteVisits() {
        return this.currentSiteVisits.length > 0;
    }

    // ── Store metric formatters ──────────────────────────────────
    get currentStoreDemandScore() {
        return Number(this.currentStore?.currentDemandScore || 0).toFixed(2);
    }

    get currentStoreDemandProgress() {
        return Math.min(Math.max(Number(this.currentStore?.currentDemandScore || 0), 0), 100);
    }

    get currentStoreFootfallIndex() {
        return Number(this.currentStore?.footfallIndex || 0).toFixed(2);
    }

    get currentStoreDemographicScore() {
        return Number(this.currentStore?.demographicScore || 0).toFixed(2);
    }

    get currentStoreEbitdaMargin() {
        return Number(this.currentStore?.ebitdaMargin || 0).toFixed(2);
    }

    get currentStorePaybackPeriod() {
        return Number(this.currentStore?.paybackPeriodYears || 0).toFixed(2);
    }

    handlePreviousSite() {
        if (!this.isSitePreviousDisabled) this.siteIndex -= 1;
    }

    handleNextSite() {
        if (!this.isSiteNextDisabled) this.siteIndex += 1;
    }

    handleViewGroup() {
        if (!this.group?.groupId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.group.groupId,
                objectApiName: 'RetailLocationGroup',
                actionName: 'view'
            }
        });
    }

    handleViewStore(event) {
        const storeId = event.currentTarget.dataset.storeid;
        if (!storeId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: storeId,
                objectApiName: 'RetailStore',
                actionName: 'view'
            }
        });
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
}