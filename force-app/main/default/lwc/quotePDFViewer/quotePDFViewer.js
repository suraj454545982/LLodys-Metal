import { LightningElement, api } from 'lwc';
import LightningModal from 'lightning/modal';
import savePDF from '@salesforce/apex/OfferLetterControllerExtension.savePDF'; 
import saveAndEmailPDF from '@salesforce/apex/OfferLetterControllerExtension.saveAndEmailPDF';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class QuotePDFViewer extends LightningModal {
    @api recordId;
    pdfUrl;

    connectedCallback() {
        const url = window.location.href;
        const urlParams = new URLSearchParams(new URL(url).search);
        this.recordId = urlParams.get('recordId');
        this.pdfUrl = `/apex/OfferPdf?quoteId=${this.recordId}`;
    }

    handleCancel() {
        this.close('cancel');
    }

    async handleSave() {
        try {
            await savePDF({ quoteId: this.recordId });
            this.showToast('Success', 'PDF saved successfully!', 'success');
            this.close('saved');
            window.location.href = `/lightning/r/Quote/${this.recordId}/view`;
        } catch (error) {
            const message = error.body?.message || 'An error occurred while saving the PDF.';
            this.showToast('Error', message, 'error');
        }
    }

    async handleSaveAndEmail() {
        try {
            const result = await saveAndEmailPDF({ quoteId: this.recordId });
            // Check if the result is a JSON string containing an error
            let parsedResult;
            try {
                parsedResult = JSON.parse(result);
                if (parsedResult.error) {
                    this.showToast('Error', parsedResult.error, 'error');
                    return;
                }
            } catch (e) {
                // If parsing fails, assume result is a ContentVersion Id (success case)
                this.showToast('Success', 'PDF saved successfully! Mail has been sent to Customer', 'success');
                this.close('savedAndEmail');
                window.location.href = `/lightning/r/Quote/${this.recordId}/view`;
            }
        } catch (error) {
            console.error('Error in handleSaveAndEmail:', JSON.stringify(error, null, 2));
            const message = error.body?.message || error.message || 'An unexpected error occurred while sending the email. Please try again or contact support.';
            this.showToast('Error', message, 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}