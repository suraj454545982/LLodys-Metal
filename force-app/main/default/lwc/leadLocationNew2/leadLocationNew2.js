import { LightningElement, api  } from 'lwc';
import updateLeadLocation from '@salesforce/apex/LeadCheckInController.updateLocation';

export default class LeadCreatorWithLocation extends LightningElement {
    @api recordId;
    connectedCallback() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(pos => {
                updateLeadLocation({
                    leadId: this.recordId,
                    latitude: pos.coords.latitude,
                    longitude: pos.coords.longitude
                })
                .then(() => {
                        this.errorMessage = '';
                        console.log('Lead location updated successfully');
                    })
                    .catch(error => {
                        console.log('error--');
                        this.errorMessage = 'Failed to update lead location.';
                        console.error(error);
                    });
            });
        }
    }
}

/*export default class LeadCreatorWithLocation extends LightningElement {
    @api recordId;

     connectedCallback() {
        if ('geolocation' in navigator) {
            navigator.geolocation.getCurrentPosition(
                position => {
                    updateLeadLocation({
                        leadId: this.recordId,
                        latitude: position.coords.latitude,
                        longitude: position.coords.longitude
                    })
                    .then(() => {
                        this.errorMessage = '';
                        console.log('Lead location updated successfully');
                    })
                    .catch(error => {
                        this.errorMessage = 'Failed to update lead location.';
                        console.error(error);
                    });
                },
                error => {
                    this.errorMessage = 'Unable to retrieve your location.';
                    console.error(error);
                },
                { timeout: 10000 }
            );
        } else {
            this.errorMessage = 'Geolocation is not supported by this browser.';
            console.warn(this.errorMessage);
        }
    }
}*/