import { LightningElement, api, track } from 'lwc';

export default class StoreSummaryCard extends LightningElement {

    // ── Public API ─────────────────────────────────────────────
    @track _rawValue = null;
    @track _parsed   = null;
    @track storeName = null;

    @api
    get value() { return this._rawValue; }
    set value(dto) {
        this._rawValue = dto;
        if (dto) {
            this.storeName = dto.storeName || null;
            this._parsed   = this._parse(dto.summary || null);
        }
    }

    _parse(summary) {
        if (!summary) return null;
        try {
            return typeof summary === 'string' ? JSON.parse(summary) : summary;
        } catch (e) { return null; }
    }

    // ── Availability ──────────────────────────────────────────
    get hasData()   { return !!this._parsed; }
    get showEmpty() { return !this.hasData; }

    // ── Store KPI metrics ─────────────────────────────────────
    get storeKpis() {
        const s = this._parsed && this._parsed.store;
        if (!s) return [];
        return [
            { id: 'demand',  icon: 'utility:trending', label: 'Demand Score',   value: s.demandScore,   colorClass: 'kpi-blue'   },
            { id: 'ebitda',  icon: 'utility:currency',  label: 'EBITDA Margin',  value: s.ebitdaMargin,  colorClass: 'kpi-green'  },
            { id: 'payback', icon: 'utility:clock',     label: 'Payback Period', value: s.paybackPeriod, colorClass: 'kpi-orange' }
        ];
    }

    get hasStoreKpis() { return this.storeKpis.length > 0; }

    // ── Sites ─────────────────────────────────────────────────
    get sites() {
        if (!this._parsed || !Array.isArray(this._parsed.sites)) return [];
        return this._parsed.sites.map((s, idx) => {
            const conf = parseFloat(s.confidence) || 0;
            return {
                id              : idx,
                name            : s.name,
                status          : s.status,
                assessment      : s.assessment,
                competitionLevel: s.competitionLevel,
                confidence      : conf.toFixed(1),
                confidenceStyle : `width: ${Math.min(conf, 100)}%`,
                confidenceClass : conf >= 80 ? 'conf-fill conf-high'
                                : conf >= 60 ? 'conf-fill conf-medium'
                                :              'conf-fill conf-low',
                compClass       : `comp-badge comp-${(s.competitionLevel || '').toLowerCase()}`
            };
        });
    }

    get hasSites() { return this.sites.length > 0; }

    // ── Visits ────────────────────────────────────────────────
    get visits() {
        if (!this._parsed || !Array.isArray(this._parsed.visits)) return [];
        return this._parsed.visits.map((v, idx) => ({ ...v, id: idx }));
    }

    get hasVisits() { return this.visits.length > 0; }

    // ── Readiness ─────────────────────────────────────────────
    get readiness() {
        return (this._parsed && this._parsed.summary && this._parsed.summary.readiness) || null;
    }

    get readinessPillLabel() {
        const t = (this.readiness || '').toLowerCase();
        if (/strong|high|excellent|ready/.test(t)) return '● Strong';
        if (/low|poor|weak|caution/.test(t))        return '● Caution';
        return '● Moderate';
    }

    get readinessPillClass() {
        const t = (this.readiness || '').toLowerCase();
        if (/strong|high|excellent|ready/.test(t)) return 'pill pill-high';
        if (/low|poor|weak|caution/.test(t))        return 'pill pill-low';
        return 'pill pill-moderate';
    }

    // ── Competition Risks ─────────────────────────────────────
    get competitionRisks() {
        const r = this._parsed && this._parsed.summary && this._parsed.summary.competitionRisks;
        if (!Array.isArray(r)) return [];
        return r.map((item, idx) => ({ ...item, id: idx }));
    }

    get hasCompetitionRisks() { return this.competitionRisks.length > 0; }

    // ── Actions ───────────────────────────────────────────────
    get actions() {
        const a = this._parsed && this._parsed.summary && this._parsed.summary.actions;
        if (!Array.isArray(a)) return [];
        return a.map((item, idx) => ({
            ...item,
            id        : idx,
            badgeLabel: idx === 0 ? 'Immediate' : idx === 1 ? 'Short-term' : 'Medium-term',
            badgeClass: idx === 0 ? 'action-badge badge-immediate'
                      : idx === 1 ? 'action-badge badge-short'
                      :             'action-badge badge-medium',
            itemClass : idx === 0 ? 'action-item action-immediate'
                      : idx === 1 ? 'action-item action-short'
                      :             'action-item action-medium'
        }));
    }

    get hasActions() { return this.actions.length > 0; }

}