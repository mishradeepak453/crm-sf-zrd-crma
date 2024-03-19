import { LightningElement, wire, api, track} from 'lwc';
import { FlowNavigationBackEvent, FlowNavigationNextEvent, FlowNavigationPauseEvent, FlowNavigationFinishEvent  } from 'lightning/flowSupport';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import POTENTIAL_FIELD from "@salesforce/schema/Project__c.Potential__c";

//import custom labels
import loadingMessage from "@salesforce/label/c.DUP_Loading_Message";
import openRecord from "@salesforce/label/c.DUP_Open_Record";
import projectName from "@salesforce/label/c.DUP_Project_Name";
import projectStreet from "@salesforce/label/c.DUP_Project_Street";
import projectPostalCode from "@salesforce/label/c.DUP_Project_Postal_Code";
import projectCity from "@salesforce/label/c.DUP_Project_City";
import projectTotalVolume from "@salesforce/label/c.DUP_Project_Total_Volume";
import projectStart from "@salesforce/label/c.DUP_Project_Start";
import projectBuildingOwner from "@salesforce/label/c.DUP_Project_Building_Owner";
import projectPotential from "@salesforce/label/c.DUP_Project_Potential";
import button1Label from "@salesforce/label/c.DUP_Button_1_Label";
import button2Label from "@salesforce/label/c.DUP_Button_2_Label";
import button3Label from "@salesforce/label/c.DUP_Button_3_Label";
import tableHeaderDuplicates from "@salesforce/label/c.DUP_Table_Header_Duplicates";
import tableHeaderOriginal from "@salesforce/label/c.DUP_Table_Header_Original";

//datable columns
const manualProjectColumns = [
    {
        label: projectName,
        fieldName: "pName",
        editable: false,
        sortable: false,
        hideDefaultActions: true,
        wrapText: true,
        initialWidth: 200
    },
    {
        label: projectStreet,
        fieldName: "pStreet",
        editable: false,
        sortable: false,
        hideDefaultActions: true,
        wrapText: true,
        initialWidth: 150
    },
    {
        label: projectPostalCode,
        fieldName: "pPostalCode",
        editable: false,
        sortable: false,
        hideDefaultActions: true,
        wrapText: true,
        initialWidth: 100
    },
    {
        label: projectCity,
        fieldName: "pCity",
        editable: false,
        sortable: false,
        hideDefaultActions: true,
        wrapText: true,
        initialWidth: 150
    },
    {
        label: projectTotalVolume,
        fieldName: "pTotalVolume",
        type: "currency",
        editable: false,
        sortable: false,
        hideDefaultActions: true,
        wrapText: true,
        initialWidth: 175,
        cellAttributes: { alignment: "left" }
    },
    {
        label: projectStart,
        fieldName: "pStart",
        type: "date",
        editable: false,
        sortable: false,
        hideDefaultActions: true,
        wrapText: true,
        initialWidth: 100
    },
    {
        label: projectBuildingOwner,
        fieldName: "pBuildingOwner",
        editable: false,
        sortable: false,
        hideDefaultActions: true,
        wrapText: true,
        initialWidth: 150
    },
    {
        label: projectPotential,
        fieldName: "pPotential",
        editable: false,
        sortable: false,
        hideDefaultActions: true,
        wrapText: true,
        initialWidth: 100
    }
]

const duplicateProjectColumns = [
    {
        label: projectName,
        fieldName: "pNameUrl",
        type: "url",
        typeAttributes: {
            label: { fieldName: "pName" }, 
            tooltip: openRecord,
            target: '_blank'
        },
        editable: false,
        sortable: false,
        hideDefaultActions: true,
        wrapText: true,
        initialWidth: 200
    },
    {
        label: projectStreet,
        fieldName: "pStreet",
        editable: false,
        sortable: false,
        hideDefaultActions: true,
        wrapText: true,
        initialWidth: 150
    },
    {
        label: projectPostalCode,
        fieldName: "pPostalCode",
        editable: false,
        sortable: false,
        hideDefaultActions: true,
        wrapText: true,
        initialWidth: 100
    },
    {
        label: projectCity,
        fieldName: "pCity",
        editable: false,
        sortable: false,
        hideDefaultActions: true,
        wrapText: true,
        initialWidth: 150
    },
    {
        label: projectTotalVolume,
        fieldName: "pTotalVolume",
        type: "currency",
        editable: false,
        sortable: false,
        hideDefaultActions: true,
        wrapText: true,
        initialWidth: 175,
        cellAttributes: { alignment: "left" }
    },
    {
        label: projectStart,
        fieldName: "pStart",
        type: "date",
        editable: false,
        sortable: false,
        hideDefaultActions: true,
        wrapText: true,
        initialWidth: 100
    },
    {
        label: projectBuildingOwner,
        fieldName: "pBuildingOwner",
        editable: false,
        sortable: false,
        hideDefaultActions: true,
        wrapText: true,
        initialWidth: 150
    },
    {
        label: projectPotential,
        fieldName: "pPotential",
        editable: false,
        sortable: false,
        hideDefaultActions: true,
        wrapText: true,
        initialWidth: 100
    }
]

export default class DupProjectDoubletsComp extends LightningElement {    

    //set labels
    labels = {
        loadingMessage,
        openRecord,
        button1Label,
        button2Label,
        button3Label,
        tableHeaderDuplicates,
        tableHeaderOriginal
    }

    loader = false;
    stylesLoaded = false;
    duplicateProjectColumns = duplicateProjectColumns;
    manualProjectColumns = manualProjectColumns;

    @api projectList = [];
    @api manualProjectList = [];
    @api selectedDuplicateRecordId;

    formattedDuplicateProjectList = [];
    formattedManualProjectList = [];
    recordId;
    //objectApiName = PROJECT_OBJECT;
    showContent = false;
    showRecordDetail = false;
    salesforceProjectRecordType;
    //potentialPicklistValues;
    //progressPicklistValues;

    buttonPrevNavigation = "BACK";
    buttonNextNavigation = "NEXT";

    button1Id = "Button1Id";
    button2Id = "Button2Id";
    button3Id = "Button3Id";

    @api selectedButtonId;

    // get Potential__c picklist values for default record type 012000000000000AAA (stays always the same)
    @wire(getPicklistValues, {
        recordTypeId: "012000000000000AAA",
        fieldApiName: POTENTIAL_FIELD
    })
    potentialPicklistValues;

    renderedCallback() {
        if(!this.showContent) {

            this.formattedManualProjectList = this.manualProjectList.map((record) => {
                return {
                    pName: record.Name,
                    pStreet: record.Project_Address__Street__s,
                    pPostalCode: record.Project_Address__PostalCode__s,
                    pCity: record.Project_Address__City__s,
                    pTotalVolume: record.Total_Volume__c,
                    pStart: record.Project_Construction_Start__c,
                    pBuildingOwner: record.Building_Owner__c,
                    pPotential: this.formatMultiselectPicklist(this.potentialPicklistValues, record.Potential__c)
                };
            });

            this.formattedDuplicateProjectList = this.projectList.map((record) => {
                return {
                    pNameUrl: "/" + record.Id,
                    pName: record.Name,
                    pStreet: record.Street__c,
                    pPostalCode: record.Postal_Code__c,
                    pCity: record.City__c,
                    pTotalVolume: record.Total_Volume__c,
                    pStart: record.Project_Construction_Start__c,
                    pBuildingOwner: record.Building_Owner__c,
                    pPotential: this.formatMultiselectPicklist(this.potentialPicklistValues, record.Potential__c)
                };
            });

            this.showContent = true;
        }
    }

    //handle multiselect picklist
    formatMultiselectPicklist(picklistValues, picklistValue) {
        let formattedPicklistValue = '';
        let picklistValueList = [];
        picklistValueList = (picklistValue != undefined && picklistValue != null && picklistValue.includes(';')) ? picklistValue.split(';') : picklistValue;
        if(picklistValueList != undefined && picklistValueList != null && picklistValueList.length > 1) {
            for (let i = 0; i < picklistValueList.length; i++) {
                formattedPicklistValue += (this.getPicklistLabel(picklistValues, picklistValueList[i]) + '; ');
            }
            formattedPicklistValue = formattedPicklistValue.slice(0, -2); 
        } else if(picklistValueList != undefined && picklistValueList != null) {
            formattedPicklistValue = this.getPicklistLabel(picklistValues, picklistValue);
        } else {
            formattedPicklistValue = '';
        }
        return formattedPicklistValue;
    }

    //get picklist label by API value
    getPicklistLabel(picklistValues, picklistValue) {
        return picklistValues.data?.values?.filter(
            (r) => r.value === picklistValue
        )[0]?.label;
    }

    handleButton1() {
        this.selectedButtonId = this.button1Id;
        this.handleNavigation(this.buttonPrevNavigation);
    }

    handleButton2() {
        this.selectedButtonId = this.button2Id;
        this.handleNavigation(this.buttonNextNavigation);
    }

    handleButton3() {
        this.selectedButtonId = this.button3Id;
        this.handleNavigation(this.buttonNextNavigation);
    }

    //handle navigation
    handleNavigation(action) {
        switch(action){
            case "NEXT":
                const navigateNextEvent = new FlowNavigationNextEvent();
                this.dispatchEvent(navigateNextEvent);
                break;
            case "BACK":
                const navigateBackEvent = new FlowNavigationBackEvent();
                this.dispatchEvent(navigateBackEvent);
                break;
            case "PAUSE":
                const navigatePauseEvent = new FlowNavigationPauseEvent();
                this.dispatchEvent(navigatePauseEvent);
                break;
            case "FINISH":
                const navigateFinishEvent = new FlowNavigationFinishEvent();
                this.dispatchEvent(navigateFinishEvent);
                break;
        }
    }

    //error handling
    handleError(error) {
        console.log(ERROR + ": " + JSON.stringify(error));
        this.loader = false;

        if (error?.status === 500) {
            this.errorMsg = this.labels.server_unreachable_error;
        } else if (Array.isArray(error.body)) {
            this.errorMsg = error.body.map((e) => e.message).join(", ");
        } else if (typeof error.body.message === "string") {
            this.errorMsg = error.body.message;
        } else {
            this.errorMsg = this.labels.unknown_error;
        }
    }
}