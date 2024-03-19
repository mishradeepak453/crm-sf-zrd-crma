/**
 * SF-854 Feld "ibau Rückverlinkung"
 *
 * BISBackLinkGenerator
 *
 * @author Daniel Gette
 *
 * @version 17.02.2022 creation
 *
 */

import {LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateLinkForProject from '@salesforce/apex/BISBackLinkGenerator.generateLinkForProject';
import errorLable from '@salesforce/label/c.Error_Ibau_Backlink';

export default class BisBacklinkComp extends LightningElement {
    @track url;
    @api recordId;
    connectedCallback() {
        generateLinkForProject({ projectId: this.recordId })
            .then(urlResult => {
                console.log(urlResult)
                this.url = urlResult;
            })
            .catch(error => {
                let errorMessage;
                if (Array.isArray(error.body)) {
                    errorMessage = error.body.map(e => e.message).join(', ');
                } else if (typeof error.body.message === 'string') {
                    errorMessage = error.body.message;
                }
                console.log(errorMessage);

                this.showToast();
            });
    }
    
    showToast() {
        const event = new ShowToastEvent({
            message: errorLable,
            variant: 'error',
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }
}