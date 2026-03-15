import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent, FlowNavigationNextEvent } from 'lightning/flowSupport';


export default class Leadtest extends LightningElement {

    @api recordId;
    @api latitude;
    @api longitude;

    connectedCallback() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                position => {
                    this.latitude = position.coords.latitude;
                    this.longitude = position.coords.longitude;

                    // Send values to Flow
                    this.dispatchEvent(new FlowAttributeChangeEvent('latitude', this.latitude));
                    this.dispatchEvent(new FlowAttributeChangeEvent('longitude', this.longitude));

                    // Auto-move to next screen
                    this.dispatchEvent(new FlowNavigationNextEvent());
                },
                error => {
                    console.error('Geolocation failed:', error.message);
                },
                {
                    enableHighAccuracy: true,
                    timeout: 10000,
                    maximumAge: 0
                }
            );
        } else {
            console.error('Geolocation not supported on this device.');
        }
    }
}