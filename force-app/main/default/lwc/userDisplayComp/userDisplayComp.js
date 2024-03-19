/**
 * SF-1239 Projekt - Benutzer in zugew. Vertriebsgebieten
 * lwc that displays users in a list
 *
 * @author miriam.ida.tyroller@accenture.com
 *
 * @version 2023-10-13  miriam.ida.tyroller@accenture.com       creation
 */

import { LightningElement, api, wire, track } from 'lwc';
import {CurrentPageReference} from 'lightning/navigation';
import queryUserData from '@salesforce/apex/LWCHandlerUserDisplayComp.queryUserData';
import NameColumnLabel from '@salesforce/label/c.User_Display_Comp_Name_Column';
import EmailColumnLabel from '@salesforce/label/c.User_Display_Comp_Email_Column';
import RoleColumnLabel from '@salesforce/label/c.User_Display_Comp_Role_Column';
import TerritoryColumnLabel from '@salesforce/label/c.User_Display_Comp_Territory_Column';

export default class UserDisplayComp extends LightningElement {

    @api recordId;
    recId = '';
    loaded = false;
    currentObject = '';
    @track usersInTerritory = [];

    @track columns = [
        {
            label: NameColumnLabel,
            fieldName: 'nameUrl',
            type: 'url',
            typeAttributes: {label: { fieldName: 'name' }, 
            target: '_blank'},
            initialWidth: 140,
            sortable: true
        },
        {
            label: EmailColumnLabel,
            fieldName: 'email',
            type: 'text',
            sortable: true
        },
        {
            label: RoleColumnLabel,
            fieldName: 'role',
            type: 'text',
            sortable: true
        },
        {
            label: TerritoryColumnLabel,
            fieldName: 'territory',
            type: 'text',
            sortable: true
        }
    ];


    @wire(CurrentPageReference) getpageRef(pageRef) {
        this.currentObject = JSON.stringify(pageRef.attributes.objectApiName);
        console.log('current Object: ' + this.currentObject);
    }

    @wire( queryUserData, {currentObject: '$currentObject', recordId: '$recordId'}) wiredUserData(result) {
        const { data, error } = result;
        if (data) {
            console.log('data '+JSON.stringify(data))
            this.usersInTerritory = data;
            this.loaded = true;
            this.error = undefined;
        } 
        else if (error) {
            this.error = error;
            console.log('## error '+ this.error);
            this.availableListViews = undefined;
        }
    }

}