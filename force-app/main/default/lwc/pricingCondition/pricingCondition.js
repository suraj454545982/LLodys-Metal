import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPricingConditions from '@salesforce/apex/PricingConditionController.getPricingConditions';
import savePricingConditions from '@salesforce/apex/PricingConditionController.savePricingConditions';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import CONDITION_TYPE_FIELD from '@salesforce/schema/Sales_Contract_Line_Item__c.Condition_Type__c';

export default class PricingConditionTab extends LightningElement {
    @api recordId;

    @track conditionType = '';
    @track amount = '';
    @track currency = '';
    @track pricingConditions = [];

    @track columns = [
        { label: 'Condition Type', fieldName: 'Condition_type', type: 'text' },
        { label: 'Amount', fieldName: 'Amount', type: 'text' },
        { label: 'Condition Unit', fieldName: 'Condition_Unit', type: 'text' },
        {
            type: 'action',
            typeAttributes: { rowActions: [{ label: 'Delete', name: 'delete' }] }
        }
    ];

    @track conditionTypeOptions = [];

    percentageTypes = ['JOCG', 'JOIG', 'JOSG', 'JTC1', 'ZKO2'];

    // --------------------------
    // CLEANING FUNCTION (IMPORTANT)
    // --------------------------
    cleanForBackend(list) {
        return list.map(item => {
            const isPercent = this.percentageTypes.includes(item.Condition_type);

            return {
                Condition_type: item.Condition_type,
                Amount: String(item.Amount).replace('%', ''),  // ALWAYS remove %
                Condition_Unit: isPercent ? '' : item.Condition_Unit,
                Locked: item.Locked || false   // ⭐ ADD THIS
            };
        });
    }

    @wire(getObjectInfo, { objectApiName: 'Sales_Contract_Line_Item__c' })
    objectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: CONDITION_TYPE_FIELD
    })
    picklistValuesHandler({ data, error }) {
        if (data) {
            this.conditionTypeOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
        }
    }

    connectedCallback() {
        this.loadPricingConditions();
    }


    get filteredConditionTypeOptions() {
        if (!this.pricingConditions || this.pricingConditions.length === 0) {
            return this.conditionTypeOptions;
        }

        const usedTypes = new Set(
            this.pricingConditions.map(item => item.Condition_type)
        );

        return this.conditionTypeOptions.filter(
            option => !usedTypes.has(option.value)
        );
    }

    // UI labels
    get amountLabel() {
        return this.percentageTypes.includes(this.conditionType)
            ? 'Percentage (%)'
            : 'Amount';
    }

    get computedStep() {
        return this.percentageTypes.includes(this.conditionType)
            ? '0.001'   
            : '0.001';  
    }

    get computedUnit() {
        return this.percentageTypes.includes(this.conditionType)
            ? '%'
            : this.currency;
    }

    // --------------------------
    // LOAD EXISTING DATA
    // --------------------------
    loadPricingConditions() {
        getPricingConditions({ recordId: this.recordId })
            .then(result => {
                this.currency = result.Currency || '';

                this.pricingConditions = (result.Pricing_Conditions || []).map((item, index) => {
                    const isPercent = this.percentageTypes.includes(item.Condition_type);

                    return {
                        ...item,
                        Amount: item.Amount,                          // plain number
                        Condition_Unit: isPercent ? '%' : item.Condition_Unit,
                        id: index
                    };
                });
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || error.message, 'error');
            });
    }

    // Handlers
    handleConditionTypeChange(event) {
        this.conditionType = event.detail.value;
    }

    handleAmountChange(event) {
        this.amount = event.detail.value;
    }

    // --------------------------
    // SAVE
    // --------------------------
    handleSave() {
        if (!this.conditionType || !this.amount) {
            this.showToast('Error', 'Please fill all required fields', 'error');
            return;
        }

        const cleanAmount = String(this.amount).replace('%', '');

        const isPercent = this.percentageTypes.includes(this.conditionType);

        const newCondition = {
            Condition_type: this.conditionType,
            Amount: cleanAmount,                  // ALWAYS clean number
            Condition_Unit: isPercent ? '' : this.currency
        };

        const updated = [...this.pricingConditions, newCondition];

        // FINAL CLEAN BEFORE SAVING TO BACKEND
        const cleanList = this.cleanForBackend(updated);

        savePricingConditions({
            recordId: this.recordId,
            pricingConditions: JSON.stringify({ Pricing_Conditions: cleanList })
        })
            .then(() => {
                // UI display mapping
                this.pricingConditions = cleanList.map((item, index) => {
                    const isPercentType = this.percentageTypes.includes(item.Condition_type);
                    return {
                        ...item,
                        Condition_Unit: isPercentType ? '%' : item.Condition_Unit,
                        id: index
                    };
                });

                this.resetForm();
                this.showToast('Success', 'Pricing condition saved successfully', 'success');
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || error.message, 'error');
            });
    }

    handleAddNew() {
        this.resetForm();
    }

    resetForm() {
        this.conditionType = '';
        this.amount = '';
    }

    // --------------------------
    // DELETE
    // --------------------------
    handleRowAction(event) {
        const rowId = event.detail.row.id;

        const updated = this.pricingConditions.filter(item => item.id !== rowId);

        const cleanList = this.cleanForBackend(updated);

        savePricingConditions({
            recordId: this.recordId,
            pricingConditions: JSON.stringify({ Pricing_Conditions: cleanList })
        })
            .then(() => {
                this.pricingConditions = cleanList.map((item, index) => {
                    const isPercent = this.percentageTypes.includes(item.Condition_type);
                    return {
                        ...item,
                        Condition_Unit: isPercent ? '%' : item.Condition_Unit,
                        id: index
                    };
                });

                this.showToast('Success', 'Pricing condition deleted successfully', 'success');
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || error.message, 'error');
            });
    }

    // Toast
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}