import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import fetchLedgerBalance from '@salesforce/apex/LedgerBalanceController.fetchLedgerBalance';

export default class SapLedgerBalance extends LightningElement {

    customerAccount = '';
    companyCode = '';
    postingDate = '';

    balanceData;

    handleCustomerAccount(event) {
        this.customerAccount = event.target.value;
    }

    handleCompanyCode(event) {
        this.companyCode = event.target.value;
    }

    handlePostingDate(event) {
        this.postingDate = event.target.value;
    }

    handleFetchBalance() {

        const inputs = this.template.querySelectorAll('lightning-input');

        let isValid = true;

        inputs.forEach(input => {
            if (!input.checkValidity()) {
                input.reportValidity();
                isValid = false;
            }
        });

        if (!isValid) {
            return;
        }

        const requestPayload = {

            Company_Code: this.companyCode,
            Customer: this.customerAccount,
            Open_Item_Key_Date: this.formatDate(this.postingDate)

        };

        fetchLedgerBalance({ requestWrapperJson: JSON.stringify(requestPayload) })
            .then(result => {

                const parsedResponse = JSON.parse(result.responseBody);

                this.balanceData = parsedResponse;

            })
            .catch(error => {

                console.error(error);

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Failed to fetch ledger balance',
                        variant: 'error'
                    })
                );

            });

    }

    formatDate(dateValue) {

        if (!dateValue) {
            return '';
        }

        const date = new Date(dateValue);

        const day = String(date.getDate()).padStart(2, '0');
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const year = date.getFullYear();

        return `${day}.${month}.${year}`;

    }

}