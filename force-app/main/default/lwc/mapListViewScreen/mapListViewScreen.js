/**
* SF-1134 Anzeige von Projekten und Accounts auf einer grafischen Karte
* lwc to display projects on a graphical map
*
* @author miriam.ida.tyroller@accenture.com
*
* @version 2023-09-20  miriam.ida.tyroller@accenture.com       creation
*/

import {LightningElement,track, wire} from 'lwc';
import queryUserListViews from '@salesforce/apex/LWCHandlerMapComp.queryUserListViews';
import ProjectHeadlineLabel from '@salesforce/label/c.Map_Comp_Project_Headline';
import AccountHeadlineLabel from '@salesforce/label/c.Map_Comp_Account_Headline';
import ComboboxLabel from '@salesforce/label/c.Map_Comp_Combobox_Label';
import DefaultLabel from '@salesforce/label/c.Map_Comp_Combobox_Default';
import OpenMapButtonLabel from '@salesforce/label/c.Map_Comp_Open_Map_Button_Label';
import LocationButtonLabel from '@salesforce/label/c.Map_Comp_Location_Button_Label';
import LocationButtonHeadline from '@salesforce/label/c.Map_Comp_Location_Button_Headline';
import {CurrentPageReference} from 'lightning/navigation';
import FORM_FACTOR from '@salesforce/client/formFactor'
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class MapListViewScreen extends LightningElement {

    @track isModalMapCompOpen = false;
    @track listView = '';
    @track availableListViews;
    @track fieldsInfo=[];
    @track value = '';
    loaded = false;
    valueChosen = true;
    SobjectType = '';
    currentUrl = '';
    currentDevice = FORM_FACTOR;
    @track myLocation;

    @track latitude;
    @track longitude;

    label = {
        ComboboxLabel,
        DefaultLabel,
        OpenMapButtonLabel,
        LocationButtonLabel,
        LocationButtonHeadline
    };

    get headLineLabel(){
        if(this.currentUrl.includes('Project')){
            return ProjectHeadlineLabel;
        }else if(this.currentUrl.includes('Account')){
            return AccountHeadlineLabel;
        }
    }

    get isMobile(){
        if(this.currentDevice == 'Large'){
            return false;
        }
        else{
            return true;
        }
    }

    @wire(CurrentPageReference) getpageRef(pageRef) {
        this.currentUrl = JSON.stringify(pageRef.attributes.apiName);
    }

    openModalMapComp() {
        this.isModalMapCompOpen = true;
    }

    handleModalMapCompChange(event) {
        this.isModalMapCompOpen = event.detail.status;
    }

    @wire( queryUserListViews, {currentUrl: '$currentUrl'}) wiredUserListViews( result ) {
        const { data, error } = result;
        if (data) {
            for(var key in data){
                this.obj={label:data[key].Name, value:data[key].Id};
                this.fieldsInfo.push(this.obj);
            }
            this.loaded = true;
            this.error = undefined;
        } 
        else if (error) {
            this.error = error;
            console.log('## error '+ JSON.stringify(this.error));
            this.availableListViews = undefined;
        }
    }

    handleComboboxChange(event) {
        this.value = event.detail.value;
        this.valueChosen = false;
    }
 
   // Format Location object for use with lightning-map base component
   get currentLocationAsMarker() {
       return [{
           location: {
               Latitude: this.latitude,
               Longitude: this.longitude
           },
           title: 'Current Location'
       }]
   }

    fetchUserCurrentLocation() {  
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(position => {

                // Get the Latitude and Longitude from Geolocation API
                this.latitude = position.coords.latitude;
                this.longitude = position.coords.longitude; 
                
                //console.log('latitude: ' + position.coords.latitude);
                //console.log('longitude: ' + position.coords.longitude);
                
            });
        }
        else {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Location Service is not available for your device',
                    variant: 'error'
                })
            );
        }
    }
}