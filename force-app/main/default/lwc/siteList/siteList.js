import { LightningElement, api } from 'lwc';

export default class SiteList extends LightningElement {
    @api value;

    get sites() {
        try {
            console.log('siteList value:', this.value);
            const stringified = JSON.stringify(this.value);
            return JSON.parse(stringified ? stringified : '[]');
        } catch (e) {
            return [];
        }
    }

    get hasSites() {
        return this.sites.length > 0;
    }

    get siteCount() {
        return this.sites.length;
    }
}