import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getOrderItemPricing from '@salesforce/apex/PricingConditionController.getOrderItemPricing';
import saveOrderItemPricing from '@salesforce/apex/PricingConditionController.saveOrderItemPricing';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import ORDER_ITEM_OBJECT from '@salesforce/schema/OrderItem';
import CONDITION_TYPE_FIELD from '@salesforce/schema/OrderItem.Condition_Type__c';

const MASTER_RECORD_TYPE_ID = '012000000000000AAA';

export default class PricingConditionOrderItem extends LightningElement {

    @api recordId;
    objectInfo;
    @track conditionType = '';
    @track amount = '';
    @track currency = '';
    @track pricingConditions = [];
    @track conditionTypeOptions = [];

    percentageTypes = ['JOCG', 'JOIG', 'JOSG', 'JTC1', 'ZKO2'];

    columns = [
        { label: 'Condition Type', fieldName: 'Condition_type', type: 'text' },
        { label: 'Amount', fieldName: 'Amount', type: 'text' },
        { label: 'Condition Unit', fieldName: 'Condition_Unit', type: 'text' },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [{ label: 'Delete', name: 'delete' }]
            }
        }
    ];

    // --------------------------
    // OBJECT INFO (for picklist)
    // --------------------------
    /*@wire(getObjectInfo, {
        objectApiName: ORDER_ITEM_OBJECT
    })
    objectInfoHandler({ data, error }) {

        if (data) {
            console.log('OBJECT INFO LOADED');
            console.log(JSON.stringify(data,null,2));
            console.log('defaultRecordTypeId = ', data.defaultRecordTypeId);
        }

        if (error) {
            console.error('OBJECT INFO ERROR', error);
        }

        // VERY IMPORTANT — keep this line so other wires still work
        this.objectInfo = { data, error };
    }*/

    @wire(getPicklistValues, {
        recordTypeId: MASTER_RECORD_TYPE_ID,
        fieldApiName: CONDITION_TYPE_FIELD
    })
    picklistValuesHandler({ data }) {
        if (data) {
            this.conditionTypeOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
        }
    }


    // --------------------------
    // LIFECYCLE
    // --------------------------
    connectedCallback() {
        this.loadPricingConditions();
    }


    // --------------------------
    // LOAD DATA
    // --------------------------
    loadPricingConditions() {
        getOrderItemPricing({ recordId: this.recordId })
            .then(result => {

                this.currency = result.Currency || '';

                this.pricingConditions =
                    (result.Pricing_Conditions || [])
                        .map((item, index) => {

                            const isPercent =
                                this.percentageTypes.includes(
                                    item.Condition_type
                                );

                            return {
                                ...item,
                                Condition_Unit:
                                    isPercent ? '%' : item.Condition_Unit,
                                id: index
                            };
                        });

            })
            .catch(error => {
                this.showToast(
                    'Error',
                    error.body?.message || error.message,
                    'error'
                );
            });
    }

    // --------------------------
    // COMPUTED
    // --------------------------
    get filteredConditionTypeOptions() {

        const used = new Set(
            this.pricingConditions.map(i => i.Condition_type)
        );

        return this.conditionTypeOptions.filter(
            opt => !used.has(opt.value)
        );
    }

    get amountLabel() {
        return this.percentageTypes.includes(this.conditionType)
            ? 'Percentage (%)'
            : 'Amount';
    }

    get computedUnit() {
        return this.percentageTypes.includes(this.conditionType)
            ? '%'
            : this.currency;
    }

    // --------------------------
    // CLEAN FOR BACKEND
    // --------------------------
    cleanForBackend(list) {

        return list.map(item => {

            const isPercent =
                this.percentageTypes.includes(
                    item.Condition_type
                );

            return {
                Condition_type: item.Condition_type,
                Amount: String(item.Amount).replace('%', ''),
                Condition_Unit: isPercent ? '' : item.Condition_Unit
            };
        });
    }

    // --------------------------
    // HANDLERS
    // --------------------------
    handleConditionTypeChange(e) {
        this.conditionType = e.detail.value;
    }

    handleAmountChange(e) {
        this.amount = e.detail.value;
    }

    handleSave() {

        if (!this.conditionType || !this.amount) {
            this.showToast(
                'Error',
                'Please fill all required fields',
                'error'
            );
            return;
        }

        const isPercent =
            this.percentageTypes.includes(this.conditionType);

        const newCondition = {
            Condition_type: this.conditionType,
            Amount: String(this.amount).replace('%', ''),
            Condition_Unit: isPercent ? '' : this.currency
        };

        const updated = [
            ...this.pricingConditions,
            newCondition
        ];

        const cleanList = this.cleanForBackend(updated);

        saveOrderItemPricing({
            recordId: this.recordId,
            pricingConditions:
                JSON.stringify({
                    Pricing_Conditions: cleanList
                })
        })
            .then(() => {

                this.pricingConditions =
                    cleanList.map((item, index) => {

                        const isPercentType =
                            this.percentageTypes.includes(
                                item.Condition_type
                            );

                        return {
                            ...item,
                            Condition_Unit:
                                isPercentType
                                    ? '%'
                                    : item.Condition_Unit,
                            id: index
                        };
                    });

                this.resetForm();

                this.showToast(
                    'Success',
                    'Order item pricing saved successfully',
                    'success'
                );
            })
            .catch(error => {
                this.showToast(
                    'Error',
                    error.body?.message || error.message,
                    'error'
                );
            });
    }

    handleRowAction(event) {

        const rowId = event.detail.row.id;

        const updated =
            this.pricingConditions
                .filter(i => i.id !== rowId);

        const cleanList =
            this.cleanForBackend(updated);

        saveOrderItemPricing({
            recordId: this.recordId,
            pricingConditions:
                JSON.stringify({
                    Pricing_Conditions: cleanList
                })
        })
            .then(() => {

                this.pricingConditions =
                    cleanList.map((item, index) => {

                        const isPercent =
                            this.percentageTypes.includes(
                                item.Condition_type
                            );

                        return {
                            ...item,
                            Condition_Unit:
                                isPercent
                                    ? '%'
                                    : item.Condition_Unit,
                            id: index
                        };
                    });

                this.showToast(
                    'Success',
                    'Pricing deleted successfully',
                    'success'
                );
            })
            .catch(error => {
                this.showToast(
                    'Error',
                    error.body?.message || error.message,
                    'error'
                );
            });
    }

    handleAddNew() {
        this.resetForm();
    }

    resetForm() {
        this.conditionType = '';
        this.amount = '';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}