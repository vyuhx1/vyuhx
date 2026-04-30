import { LightningElement, api } from 'lwc';

export default class SiteEvaluationList extends LightningElement {
    @api value;

    get sites() {
        try {
            console.log('value:', this.value);
            console.log('Parsing site evaluations from value:', JSON.parse(JSON.stringify(this.value)));
            const strigified = JSON.stringify(this.value);
            return JSON.parse((strigified) ? strigified : '[]');
        } catch (e) {
            return [];
        }
    }

    get hasSites() {
        return this.sites.length > 0;
    }
}