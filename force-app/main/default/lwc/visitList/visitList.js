import { LightningElement, api, track } from 'lwc';

export default class VisitList extends LightningElement {
    @api value; // VisitResponseDTO — contains visits list + counts
    @track _currentIdx = 0;

    get _response() {
        try {
            const s = JSON.stringify(this.value);
            return s ? JSON.parse(s) : {};
        } catch (e) {
            return {};
        }
    }

    get visits()       { return this._response.visits || []; }
    get hasVisits()    { return this.visits.length > 0; }
    get totalVisits()  { return this.visits.length; }
    get currentIndex() { return this._currentIdx + 1; }
    get currentVisit() { return this.visits[this._currentIdx] || null; }
    get isFirst()      { return this._currentIdx === 0; }
    get isLast()       { return this._currentIdx === this.visits.length - 1; }

    get plannedCount()    { return this._response.plannedCount    ?? 0; }
    get inProgressCount() { return this._response.inProgressCount ?? 0; }
    get completedCount()  { return this._response.completedCount  ?? 0; }
    get cancelledCount()  { return this._response.cancelledCount  ?? 0; }

    handlePrev() {
        if (this._currentIdx > 0) this._currentIdx -= 1;
    }

    handleNext() {
        if (this._currentIdx < this.visits.length - 1) this._currentIdx += 1;
    }
}