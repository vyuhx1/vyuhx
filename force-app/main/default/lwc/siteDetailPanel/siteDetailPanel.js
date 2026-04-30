import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class SiteDetailPanel extends NavigationMixin(LightningElement) {
    @api site;

    get demandProgress() {
        return Math.min(Math.max(Number(this.site?.demandScore) || 0, 0), 100);
    }

    get demandScoreFormatted() {
        return Number(this.site?.demandScore || 0).toFixed(1);
    }

    get annualRevenueFormatted() {
        const val = Number(this.site?.estimatedAnnualRevenue || 0);
        return val.toLocaleString('en-IN', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
    }

    get footfallIndexFormatted() {
        const val = this.site?.footfallIndex;
        return val != null ? Number(val).toFixed(2) + '%' : '—';
    }

    get demographicScoreFormatted() {
        const val = this.site?.demographicScore;
        return val != null ? Number(val).toFixed(2) + '%' : '—';
    }

    get ebitdaMarginFormatted() {
        const val = this.site?.ebitdaMargin;
        return val != null ? Number(val).toFixed(2) : '—';
    }

    get paybackPeriodFormatted() {
        return Number(this.site?.paybackPeriod || 0).toFixed(1);
    }

    get competitionBadgeClass() {
        const level = (this.site?.competitionLevel || '').toLowerCase();
        if (level === 'low') return 'comp-badge comp-low';
        if (level === 'high') return 'comp-badge comp-high';
        return 'comp-badge comp-medium';
    }

    get hasProposedSites() {
        return (this.site?.proposedSites?.length || 0) > 0;
    }

    get proposedSitesWithIndex() {
        return (this.site?.proposedSites || []).map(s => ({
            ...s,
            siteLabel: s.siteName
        }));
    }

    handleSiteNavigation(event) {
        event.preventDefault();
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
}