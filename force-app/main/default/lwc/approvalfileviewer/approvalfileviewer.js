import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getApprovalFiles from '@salesforce/apex/ApprovalFilesController.getApprovalFiles';

export default class Approvalfileviewer extends NavigationMixin(LightningElement) {
   @api recordId; // ProcessInstanceWorkitem Id

    files = [];
    error;

    @wire(getApprovalFiles, { workItemId: '$recordId' })
    wiredFiles({ data, error }) {
        if (data) {
            this.files = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.files = [];
        }
    }

    previewFile(event) {
        const docId = event.currentTarget.dataset.id;

        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state: {
                selectedRecordId: docId
            }
        });
    }

    get hasFiles() {
        return this.files.length > 0;
    }
}