import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class SiteEvaluationCard extends NavigationMixin(LightningElement) {
    @api site;

    get competitionVariant() {
        const level = (this.site?.competitionLevel || '').toLowerCase();
        if (level === 'low') return 'success';
        if (level === 'high') return 'error';
        return 'warning';
    }

    get demandProgress() {
        const val = Number(this.site?.demandScore) || 0;
        return Math.min(Math.max(val, 0), 100);
    }

    get demandScoreFormatted() {
        return Number(this.site?.demandScore || 0).toFixed(2);
    }

    get footfallIndexFormatted() {
        return Number(this.site?.footfallIndex || 0).toFixed(2) + '%';
    }

    get demographicScoreFormatted() {
        return Number(this.site?.demographicScore || 0).toFixed(2) + '%';
    }

    get annualRevenueFormatted() {
        const val = Number(this.site?.estimatedAnnualRevenue || 0);
        return val.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }

    get ebitdaMarginFormatted() {
        return Number(this.site?.ebitdaMargin || 0).toFixed(2);
    }

    get paybackPeriodFormatted() {
        return Number(this.site?.paybackPeriod || 0).toFixed(2);
    }

    get hasProposedSites() {
        return this.site?.proposedSites?.length > 0;
    }

    get proposedSitesWithIndex() {
        return (this.site?.proposedSites || []).map((s, idx) => ({
            ...s,
            siteLabel: `${s.siteLabel}`
        }));
    }

    get mapMarkers() {
        if (!this.hasProposedSites) return [];
        return this.site.proposedSites
            .filter(s => s.latitude != null && s.longitude != null)
            .map((s, idx) => ({
                location: {
                    Latitude: Number(s.latitude),
                    Longitude: Number(s.longitude)
                },
                title: `${s.siteLabel}`,
                description: `Activity: ${s.competitionActivity ?? 'N/A'} | Confidence: ${s.competitionConfidence ?? 'N/A'} | Impact: ${s.competitionImpact ?? 'N/A'}`
            }));
    }

    get hasMapMarkers() {
        return this.mapMarkers.length > 0;
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

    handleViewRecord() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.site.siteId,
                objectApiName: 'RetailStore',
                actionName: 'view'
            }
        });
    }
}