import { LightningElement, track } from 'lwc';
import getAccounts from '@salesforce/apex/AccountController.getAccounts';
import createSurveyRecords from '@salesforce/apex/AccountController.createSurveyRecords';
import updateAccounts from '@salesforce/apex/AccountController.updateAccounts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AccountRecordPage extends LightningElement {
    @track accounts = [];
    @track filteredAccounts = [];
    @track selectedRows = [];
    @track draftValues = [];
    selectedRecords = [];
    @track searchKey = '';
    @track error;

    columns = [
        {
            label: 'Account Name',
            fieldName: 'recordLink',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'Name' },
                target: '_blank'
            }
        },
        { label: 'Email', fieldName: 'Company_Email_ID__c' },
        { label: 'Phone', fieldName: 'Phone' },
        { label: 'Category', fieldName: 'Category__c' },
        {
            label: 'Additional Emails',
            fieldName: 'Additional_Mails__c',
            editable: true,
            cellAttributes: {
                class: { fieldName: 'hasInvalidEmail' }
            }
        }

    ];
    @track isModalOpen = false;
    @track selectedAccountIdForSM = null;


    connectedCallback() {
        this.fetchAccounts();
    }
    get isEditing() {
        return this.draftValues && this.draftValues.length > 0;
    }
    get accountOptions() {
        return this.accounts.map(acc => ({
            label: `${acc.Name} - ${acc.Category__c || 'N/A'}`,
            value: acc.Id
        }));
    }



    fetchAccounts() {
        getAccounts()
            .then((result) => {
                this.accounts = result.map(acc => ({
                    ...acc,
                    recordLink: '/' + acc.Id,
                    isSticky: 'slds-is-sticky',
                    hasInvalidEmail: this.invalidEmailRows.has(acc.Id) ? 'invalid-email-cell' : ''
                }));
                this.filteredAccounts = this.accounts;
                this.error = undefined;
            })
            .catch((error) => {
                this.error = error.body ? error.body.message : error.message;
                this.accounts = [];
                this.filteredAccounts = [];
            });
    }

    handleSearchKeyChange(event) {
        this.searchKey = event.target.value.toLowerCase();
        if (this.searchKey.length >= 2) {
            this.filteredAccounts = this.accounts.filter(acc =>
                acc.Name && acc.Name.toLowerCase().includes(this.searchKey)
            );
        } else {
            this.filteredAccounts = this.accounts;
        }
        this.selectedRows = [];
        this.selectedRecords = [];
        this.draftValues = [];
    }

    handleRowSelection(event) {
        this.selectedRecords = event.detail.selectedRows;
        this.selectedRows = this.selectedRecords.map(row => row.Id);
    }
    @track invalidEmailRows = new Set();

    handleCellChange(event) {
        const changes = event.detail.draftValues;
        const invalidRows = new Set();

        for (const change of changes) {
            console.log('changes: ', JSON.stringify(changes));
            if (change.Additional_Mails__c) {
                const emails = change.Additional_Mails__c.split(',').map(e => e.trim());
                const invalidEmails = emails.filter(email => !this.validateEmail(email));

                if (invalidEmails.length > 0) {
                    this.showToast('Error', `Invalid email(s): ${invalidEmails.join(', ')}`, 'error');
                    invalidRows.add(change.Id);
                }
            }
        }

        this.invalidEmailRows = invalidRows;
        console.log('changes Final: ', JSON.stringify(changes));

        if (invalidRows.size === 0) {
            // Ensure draftValues keeps only one entry per Id
            const draftMap = new Map(this.draftValues?.map(d => [d.Id, { ...d }]) || []);
            for (const change of changes) {
                draftMap.set(change.Id, { ...change }); // Replace or add the change
            }
            this.draftValues = Array.from(draftMap.values());
        }
        console.log('draftValues: ', JSON.stringify(this.draftValues));

    }

    validateEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }


    handleSubmitSM() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.selectedAccountIdForSM = null;
    }

    handleAccountSelection(event) {
        this.selectedAccountIdForSM = event.detail.value;
    }

    handleSMModalSubmit() {
        if (!this.selectedAccountIdForSM) {
            this.showToast('Error', 'Please select an account before submitting.', 'error');
            return;
        }
        createSurveyRecords({ selectedAccountIds: this.selectedAccountIdForSM, mail: false })
            .then(result => {
                console.log('Created Survey:', JSON.stringify(result));
                window.location.href = `/lightning/r/Survey__c/${result[0].Id}/view`;

                this.showToast('Success', 'Survey records created successfully.', 'success');
                this.closeModal();
            })
            .catch(error => {
                this.showToast('Error', error.body.message || error.message, 'error');
            });

    }

    handleSave() {
        const updatedFields = this.draftValues;

        if (!updatedFields || updatedFields.length === 0) {
            this.showToast('Warning', 'No changes to save.', 'warning');
            return;
        }

        // Prepare records to update
        const recordsToUpdate = updatedFields.map(draft => ({
            Id: draft.Id,
            Additional_Mails__c: draft.Additional_Mails__c
        }));

        // Call Apex to update records
        updateAccounts({ accountsToUpdate: recordsToUpdate })
            .then(() => {
                this.showToast('Success', 'Account records updated successfully.', 'success');
                return this.fetchAccounts(); // Refresh data
            })
            .then(() => {
                this.draftValues = []; // Clear draft values
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || error.message, 'error');
            });
    }


    handleCancel(event) {
        // Clear draft values on cancel
        this.draftValues = [];
    }

    handleSubmit() {
        if (this.selectedRecords.length === 0) {
            this.showToast('Error', 'Please select at least one account before submitting.', 'error');
            return;
        }

        const selectedIds = this.selectedRecords.map(row => row.Id);

        createSurveyRecords({ selectedAccountIds: selectedIds , mail: true})
            .then(() => {
                this.showToast('Success', 'Survey records created successfully.', 'success');
                this.selectedRows = [];
                this.selectedRecords = [];
            })
            .catch(error => {
                this.showToast('Error', error.body.message || error.message, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}