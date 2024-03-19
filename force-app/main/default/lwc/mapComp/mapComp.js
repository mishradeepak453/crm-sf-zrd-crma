/**
* SF-1134 Anzeige von Projekten und Accounts auf einer grafischen Karte
* lwc to display projects on a graphical map
*
* @author miriam.ida.tyroller@accenture.com
*
* @version 2023-09-20  miriam.ida.tyroller@accenture.com       creation
*/

import {LightningElement, api, track, wire} from 'lwc';
import queryMapData from '@salesforce/apex/LWCHandlerMapComp.queryMapData';

export default class MapComp extends LightningElement {

    @api listViewId;
    @api currentUrl;
    @track mapMarkers =[];
    listView = 'hidden';
    loaded = false;

    @wire( queryMapData, {listViewId: '$listViewId', currentUrl: '$currentUrl'}) wiredMapData( result ) {
        const { data, error } = result;
        if (data) {
            this.mapMarkers = data;
            this.loaded = true;
            this.error = undefined;
        } 
        else if (error) {
            this.error = error;
            console.log('## error '+ JSON.stringify(this.error));
            this.mapMarkers = undefined;
        }
    }

    handleCloseModal() {
        this.mapMarkers =[];

        // Creates the event with the data.
        const selectedEvent = new CustomEvent("progressvaluechange", {
            detail:{
                status: false
            }
          });
          // Dispatches the event.
          this.dispatchEvent(selectedEvent);
    }

}