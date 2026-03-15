import { LightningElement, api } from 'lwc';
import updateLeadLocation from '@salesforce/apex/LeadCheckInController.updateLeadLocation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class LeadLocation extends LightningElement {
    @api recordId;
    _hasRendered = false;

    renderedCallback() {
        // Run only once
        if (this._hasRendered) return;
        this._hasRendered = true;

        // Check if browser supports geolocation
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    const latitude = position.coords.latitude;
                    const longitude = position.coords.longitude;

                    updateLeadLocation({
                        leadId: this.recordId,
                        latitude: latitude,
                        longitude: longitude
                    })
                    .then(() => {
                        this.showToast('Success', 'Location updated successfully.', 'success');
                        this.dispatchEvent(new CloseActionScreenEvent());
                    })
                    .catch(error => {
                        this.showToast('Error', error?.body?.message || 'An error occurred.', 'error');
                        this.dispatchEvent(new CloseActionScreenEvent());
                    });
                },
                (error) => {
                    this.showToast('Error', 'Could not retrieve location: ' + error.message, 'error');
                    this.dispatchEvent(new CloseActionScreenEvent());
                }
            );
        } else {
            this.showToast('Error', 'Geolocation is not supported by this browser.', 'error');
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}