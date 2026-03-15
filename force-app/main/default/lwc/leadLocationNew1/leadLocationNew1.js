import { LightningElement } from 'lwc';
import { createRecord } from 'lightning/uiRecordApi';
import LEAD_OBJECT from '@salesforce/schema/Lead';
import FIRSTNAME_FIELD from '@salesforce/schema/Lead.FirstName';
import LASTNAME_FIELD from '@salesforce/schema/Lead.LastName';
import COMPANY_FIELD from '@salesforce/schema/Lead.Company';
import updateLeadLocation from '@salesforce/apex/LeadCheckInController.updateLeadLocation';


export default class LeadCreatorWithLocation extends LightningElement {
    handleCreateLead() {
        const fields = {
            [FIRSTNAME_FIELD.fieldApiName]: 'Checkin',
            [LASTNAME_FIELD.fieldApiName]: 'User',
            [COMPANY_FIELD.fieldApiName]: 'Salesforce'
        };

        const recordInput = { apiName: LEAD_OBJECT.objectApiName, fields };

        createRecord(recordInput)
            .then(lead => {
                const leadId = lead.id;
                console.log('✅ Lead Created: ', leadId);

                if (navigator.geolocation) {
                    navigator.geolocation.getCurrentPosition(position => {
                        const lat = position.coords.latitude;
                        const lon = position.coords.longitude;

                        console.log('🌍 Location:', lat, lon);

                        updateLeadLocation({ leadId, latitude: lat, longitude: lon })
                            .then(() => {
                                console.log('📍 Lead location updated successfully.');
                            })
                            .catch(error => {
                                console.error('❌ Error updating location:', error);
                            });
                    }, error => {
                        console.error('❌ Geolocation error:', error.message);
                    });
                } else {
                    console.warn('⚠️ Geolocation is not supported in this browser.');
                }
            })
            .catch(error => {
                console.error('❌ Error creating lead:', error);
            });
    }
    
}