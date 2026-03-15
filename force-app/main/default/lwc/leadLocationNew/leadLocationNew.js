import { LightningElement } from 'lwc';
import { createRecord } from 'lightning/uiRecordApi';
import LEAD_OBJECT from '@salesforce/schema/Lead';
import FIRSTNAME_FIELD from '@salesforce/schema/Lead.FirstName';
import LASTNAME_FIELD from '@salesforce/schema/Lead.LastName';
import COMPANY_FIELD from '@salesforce/schema/Lead.Company';

import updateLeadLocation from '@salesforce/apex/LeadCheckInController.updateLeadLocation';

export default class LeadCreatorWithLocation extends LightningElement {
    createLeadAndUpdateLocation() {
        const fields = {};
        fields[FIRSTNAME_FIELD.fieldApiName] = 'Prashanti';
        fields[LASTNAME_FIELD.fieldApiName] = 'P';
        fields[COMPANY_FIELD.fieldApiName] = 'MyCompany';

        const recordInput = { apiName: LEAD_OBJECT.objectApiName, fields };

        createRecord(recordInput)
            .then(lead => {
                console.log('Lead created with Id:', lead.id);

                // Now capture browser geolocation
                if (navigator.geolocation) {
                    navigator.geolocation.getCurrentPosition(position => {
                        const latitude = position.coords.latitude;
                        const longitude = position.coords.longitude;

                        // Call Apex to update location
                        updateLeadLocation({ leadId: lead.id, latitude: latitude, longitude: longitude })
                            .then(() => {
                                console.log('Lead location updated');
                            })
                            .catch(error => {
                                console.error('Failed to update location', error);
                            });
                    });
                }
            })
            .catch(error => {
                console.error('Error creating lead:', error);
            });
    }
}