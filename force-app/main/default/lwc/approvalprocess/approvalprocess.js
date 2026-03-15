import { LightningElement, api, wire, track } from 'lwc';
import getPurchaseOrderApprovalData from '@salesforce/apex/purchaseorder.getPurchaseOrderApprovalData';

export default class Approvalprocess extends LightningElement {
    @api recordId;
    @api pageType;

    @track purchaseOrder;
    @track accountRecord;
    @track showPOComponent = false;
    @track showAccountComponent = false;

    @wire(getPurchaseOrderApprovalData, { pIWorkItemId: '$recordId', pageType: '$pageType' })
    wiredData({ data, error }) {
        if (data) {
            if (data.objectType === 'Purchase_Order__c') {
                this.purchaseOrder = data.purchaseOrder;
                this.showPOComponent = true;
            } else if (data.objectType === 'Account') {
                this.accountRecord = data.accountRecord;
                this.showAccountComponent = true;
            }
        } else if (error) {
            console.error('Error:', error);
        }
    }

    get poRecordUrl() {
        return this.purchaseOrder?.Id
            ? `/lightning/r/Purchase_Order__c/${this.purchaseOrder.Id}/view`
            : '#';
    }

    get opportunityUrl() {
    return this.purchaseOrder?.Opportunity__c
        ? `/lightning/r/Opportunity/${this.purchaseOrder.Opportunity__c}/view`
        : '#';
}

get quoteUrl() {
    return this.purchaseOrder?.Quote__c
        ? `/lightning/r/Quote/${this.purchaseOrder.Quote__c}/view`
        : '#';
}

get accountFields() {
    return [
        "Name", "Type", "Industry", "Phone", "Website", "Bank_Acc_no__c",
        "Bank_Account_Holder_Name__c", "Bank_Name__c", "Branch__c", "Category__c",
        "Company_Email_ID__c", "GST_No__c", "IFSC__c", "PAN__c", "TAN__c"
    ];
}
}





/*import { LightningElement, api, wire, track } from 'lwc';
import getPurchaseOrderApprovalData from '@salesforce/apex/purchaseorder.getPurchaseOrderApprovalData';

export default class Approvalprocess extends LightningElement {
    @api recordId;
    @api pageType;

    @track purchaseOrder;
    @track accountRecord;
    @track showPOComponent = false;
    @track showAccountComponent = false;

    @wire(getPurchaseOrderApprovalData, { pIWorkItemId: '$recordId', pageType: '$pageType' })
    wiredData({ data, error }) {
        if (data) {
            if (data.objectType === 'Purchase_Order__c') {
                this.purchaseOrder = data.purchaseOrder;
                this.showPOComponent = true;
            } else if (data.objectType === 'Account') {
                this.accountRecord = data.accountRecord;
                this.showAccountComponent = true;
            }
        } else if (error) {
            console.error('Error:', error);
        }
    }
}*/