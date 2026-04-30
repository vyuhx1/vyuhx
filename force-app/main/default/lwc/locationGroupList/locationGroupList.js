import { LightningElement, api, track } from 'lwc';

export default class LocationGroupList extends LightningElement {
    @api value;
    @track groupIndex = 0;

    get groups() {
        try {
            console.log('locationGroupList value:', this.value);
            const stringified = JSON.stringify(this.value);
            return JSON.parse(stringified ? stringified : '[]');
        } catch (e) {
            return [];
        }
    }

    get hasGroups() {
        return this.groups.length > 0;
    }

    get groupCount() {
        return this.groups.length;
    }

    get currentGroup() {
        return this.groups[this.groupIndex];
    }

    get groupPosLabel() {
        return `Group ${this.groupIndex + 1} of ${this.groupCount}`;
    }

    get isGroupPreviousDisabled() {
        return this.groupIndex === 0;
    }

    get isGroupNextDisabled() {
        return this.groupIndex >= this.groups.length - 1;
    }

    handlePreviousGroup() {
        if (!this.isGroupPreviousDisabled) this.groupIndex -= 1;
    }

    handleNextGroup() {
        if (!this.isGroupNextDisabled) this.groupIndex += 1;
    }
}