import { LightningElement, api, track } from 'lwc';

export default class RetailStoreList extends LightningElement {
    @api value;
    @track storeIndex = 0;

    get stores() {
        try {
            console.log('retailStoreList value:', this.value);
            const stringified = JSON.stringify(this.value);
            return JSON.parse(stringified ? stringified : '[]');
        } catch (e) {
            return [];
        }
    }

    get hasStores() {
        return this.stores.length > 0;
    }

    get storeCount() {
        return this.stores.length;
    }

    get currentStore() {
        return this.stores[this.storeIndex];
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
        if (!this.isStorePreviousDisabled) this.storeIndex -= 1;
    }

    handleNextStore() {
        if (!this.isStoreNextDisabled) this.storeIndex += 1;
    }
}