import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import fetchLedgerData from '@salesforce/apex/LedgerController.fetchLedgerData';

export default class SapLedgerSearch extends LightningElement {

    customerAccount = '';
    companyCode = '';
    postingDate = '';

    ledgerData = [];

    columns = [
        { label: 'Document Number', fieldName: 'Document_Number' },
        { label: 'Status', fieldName: 'Status' },
        { label: 'Account', fieldName: 'Account' },
        { label: 'Posting Date', fieldName: 'Posting_date' },
        { label: 'Doc Type', fieldName: 'Type' },
        { label: 'Net Due Date', fieldName: 'Net_Due_Date' },
        { label: 'Amount', fieldName: 'Local_Currency_Amount' },
        { label: 'Currency', fieldName: 'Local_Curreny' },
        { label: 'Reference', fieldName: 'Reference' },
        { label: 'Text', fieldName: 'Text' }
    ];

    handleCustomerAccount(event) {
        this.customerAccount = event.target.value;
    }

    handleCompanyCode(event) {
        this.companyCode = event.target.value;
    }

    handlePostingDate(event) {
        this.postingDate = event.target.value;
    }




    handleFetchLedger() {

        // Validate all inputs
        const inputs = this.template.querySelectorAll('lightning-input');

        let isValid = true;

        inputs.forEach(input => {
            if (!input.checkValidity()) {
                input.reportValidity();
                isValid = false;
            }
        });

        // Stop execution if invalid
        if (!isValid) {
            return;
        }


        const requestPayload = {

            Customer_Account: this.customerAccount,
            Company_Code: this.companyCode,
            Posting_Date: this.formatDate(this.postingDate),

        };

        console.log('SAP Request Payload');
        console.log(JSON.stringify(requestPayload, null, 2));

        fetchLedgerData({ requestWrapperJson: JSON.stringify(requestPayload) })
            .then(result => {

                console.log('Full Apex Response', result);

                const parsedResponse = JSON.parse(result.responseBody);

                console.log('Parsed Response', parsedResponse);

                // Check SAP error response
                if (parsedResponse.SFDC_Ledger_Res && parsedResponse.SFDC_Ledger_Res.message) {

                    const message = parsedResponse.SFDC_Ledger_Res.message;

                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Response Error',
                            message: message,
                            variant: 'error'
                        })
                    );

                    return;
                }

                // Success case
                this.ledgerData = parsedResponse.Ledger_Res.reverse();

                console.log('Ledger Records', JSON.stringify(this.ledgerData, null, 2));

            })
            .catch(error => {

                console.error(error);

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Unexpected error occurred',
                        variant: 'error'
                    })
                );

            });

    }

    copyToClipboard() {

        if (!this.ledgerData || this.ledgerData.length === 0) {

            this.showToast(
                'Info',
                'No data available to copy',
                'info'
            );

            return;
        }

        let table = '';

        const headers = this.columns.map(col => col.label);
        const fields = this.columns.map(col => col.fieldName);

        // Header row
        table += headers.join('\t') + '\n';

        // Data rows
        this.ledgerData.forEach(row => {

            const values = fields.map(field => row[field] || '');

            table += values.join('\t') + '\n';

        });

        navigator.clipboard.writeText(table);

        this.showToast(
            'Success',
            'Copied to clipboard successfully',
            'success'
        );

    }

    downloadExcel() {

        console.log('Download button clicked');

        if (!this.ledgerData || this.ledgerData.length === 0) {

            this.showToast(
                'Info',
                'No data available to download',
                'info'
            );

            return;
        }

        const headers = this.columns.map(col => col.label);
        const fields = this.columns.map(col => col.fieldName);

        let csv = headers.join(',') + '\n';

        this.ledgerData.forEach(row => {

            const values = fields.map(field => `"${row[field] || ''}"`);

            csv += values.join(',') + '\n';

        });

        const csvData = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csv);

        const link = document.createElement('a');

        link.href = csvData;
        link.download = 'LedgerData.csv';

        document.body.appendChild(link);

        link.click();

        document.body.removeChild(link);

        this.showToast(
            'Success',
            'Ledger downloaded successfully',
            'success'
        );

    }


    showToast(title, message, variant) {

        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });

        this.dispatchEvent(event);

    }

    formatDate(dateValue) {

        if (!dateValue) {
            return '';
        }

        const date = new Date(dateValue);
        console.log(date.getDate());
        console.log(date.getMonth());
        console.log(date.getFullYear());
        const day = String(date.getDate()).padStart(2, '0');
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const year = date.getFullYear();

        return `${day}.${month}.${year}`;

    }
}