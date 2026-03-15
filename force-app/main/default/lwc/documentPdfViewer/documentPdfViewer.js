import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import fetchDocumentPdf from '@salesforce/apex/DocumentPdfController.fetchDocumentPdf';

export default class DocumentPdfViewer extends LightningElement {

    customer = '';
    companyCode = '';
    documentNumber = '';
    postingDate = '';

    pdfUrl;
    base64Pdf;

    handleCustomer(event) {
        this.customer = event.target.value;
    }

    handleCompanyCode(event) {
        this.companyCode = event.target.value;
    }

    handleDocumentNumber(event) {
        this.documentNumber = event.target.value;
    }

    handlePostingDate(event) {
        this.postingDate = event.target.value;
    }

    fetchPdf() {

        // Validate fields
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

        const formattedDate = this.formatDate(this.postingDate);

        fetchDocumentPdf({
            customer: this.customer,
            companyCode: this.companyCode,
            documentNumber: this.documentNumber,
            postingDate: formattedDate
        })
        .then(result => {

            this.base64Pdf = result;

            // Convert Base64 to Blob
            const byteCharacters = atob(result);
            const byteNumbers = new Array(byteCharacters.length);

            for (let i = 0; i < byteCharacters.length; i++) {
                byteNumbers[i] = byteCharacters.charCodeAt(i);
            }

            const byteArray = new Uint8Array(byteNumbers);

            const blob = new Blob([byteArray], { type: 'application/pdf' });

            this.pdfUrl = URL.createObjectURL(blob);

            this.showToast(
                'Success',
                'Document ready for preview or download',
                'success'
            );

        })
        .catch(error => {

            console.error(error);

            this.showToast(
                'Error',
                'Failed to fetch document',
                'error'
            );

        });
    }

    previewPdf() {

        if (!this.pdfUrl) {
            this.showToast('Info', 'Please fetch document first', 'info');
            return;
        }

        window.open(this.pdfUrl, '_blank');

    }

    downloadPdf() {

        if (!this.pdfUrl) {
            this.showToast('Info', 'Please fetch document first', 'info');
            return;
        }

        const link = document.createElement('a');

        link.href = this.pdfUrl;
        link.download = 'Document.pdf';

        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);

        this.showToast(
            'Success',
            'PDF downloaded successfully',
            'success'
        );
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

    showToast(title, message, variant) {

        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });

        this.dispatchEvent(event);
    }

}