import { LightningElement, api, wire, track } from 'lwc';
import getOpportunityRecord from '@salesforce/apex/customapprovalprocess.getOpportunityRecord';
import getQuoteLineItems from '@salesforce/apex/customapprovalprocess.getQuoteLineItems';

export default class Approvalcustomlayout extends LightningElement {
    @api recordId;
    @api pageType;

    @track oppRecId;
    @track quoteId;
    @track opp;
    @track quote;
    @track quoteLineItems;
    @track showComponent = false;

    oppFields = [
        "Name", "StageName", "AccountId", "CloseDate", "Category__c", "Sub_Category__c", "LeadSource"
    ];

    quoteFields = [
        "Name", "AccountId", "ContactId", "Total_Quantity__c", "Quote_Grand_Total_New__c",
        "Freight__c", "TotalDiscount__c", "CentralGST__c", "StateGST__c",
        "Payment_Terms__c", "Technical_Specifications__c", "Packing_and_Forwarding_Rollup__c",
        "Shipping_and_Handling_Rollup__c", "Delivery_Terms__c", "Delivery_Description__c",
        "More_delivery_Terms__c", "ExpirationDate"
    ];

    quoteLineItemColumns = [
        { label: 'Product', fieldName: 'productName' },
        { label: 'Quantity', fieldName: 'Quantity', type: 'number' },
        { label: 'Unit Price', fieldName: 'UnitPrice', type: 'currency' },
        { label: 'Discount', fieldName: 'TotalDiscount__c', type: 'currency' },
        { label: 'Remarks', fieldName: 'Remarks__c' },
        { label: 'Total Amount', fieldName: 'Total_Amount__c', type: 'currency' }
    ];

    @wire(getOpportunityRecord, {
        pIWorkItemId: '$recordId',
        pageType: '$pageType'
    })
    wiredData({ data, error }) {
        if (data) {
            console.log('data', data);
            this.opp = data.opp;
            this.quoteId = data.quoteId;
            this.oppRecId = this.opp?.Id;
            this.showComponent = true;
        } else if (error) {
            console.error('Error in wiredData::', error);
            this.showComponent = false;
        }
    }


    @wire(getQuoteLineItems, { quoteId: '$quoteId' })
    wiredQuoteLineItems({ data, error }) {
        if (data) {
            this.quoteLineItems = data.map(item => ({
                ...item,
                productName: item.Product2?.Name || ''
            }));
        } else if (error) {
            console.error('Error fetching quote line items:', error);
        }
    }
}