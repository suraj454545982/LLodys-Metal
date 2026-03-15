import { LightningElement, api } from 'lwc';
import updateLeadLocation from '@salesforce/apex/LeadCheckInController.updateLeadLocation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class LeadLocationQuickAction extends LightningElement {
    @api recordId;

    @api
    invoke() {
        // Step 1: Show initial toast
        //this.showToast('Success', 'Check-in started. Capturing location...', 'success');

        // Step 2: Get location
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    updateLeadLocation({
                        leadId: this.recordId,
                        latitude: position.coords.latitude,
                        longitude: position.coords.longitude
                    })
                    .then(() => {
                        this.showToast('Success', 'Location updated successfully.', 'success');
                    })
                    .catch(error => {
                        this.showToast('Error', error?.body?.message || 'Error updating location.', 'error');
                    });
                },
                (error) => {
                    this.showToast('Error', 'Please Enable the Location: ' + error.message, 'error');
                }
            );
        } else {
            this.showToast('Error', 'Geolocation is not supported by this browser.', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}