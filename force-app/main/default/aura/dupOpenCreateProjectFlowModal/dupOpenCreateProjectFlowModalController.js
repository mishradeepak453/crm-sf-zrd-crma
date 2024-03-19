({
    doInit: function(component, event, helper){
        var parentRecordId = '';
        var ref = component.get("v.pageReference");
        var state = ref.state; 
        var context = state.inContextOfRef;
        if (context != null && context.startsWith("1\.")) {
            context = context.substring(2);
            var addressableContext = JSON.parse(window.atob(context));
            parentRecordId = addressableContext.attributes.recordId;
        } else {
            parentRecordId = ref.state.additionalParams;
            if(typeof parentRecordId !== 'undefined') {
                parentRecordId = parentRecordId.replace('accid=','');
                parentRecordId = parentRecordId.substring(0,15);
            }
        }
        var openCreateProjectFlowComp = component.find('openCreateProjectFlowComp');
        openCreateProjectFlowComp.openFlow(parentRecordId);

        var cmpBack = component.find('Modalbackdrop');
        var cmpTarget = component.find('Modalbox');
        $A.util.addClass(cmpTarget, 'slds-fade-in-open');
        $A.util.addClass(cmpBack, 'slds-backdrop--open');
    },
    closeModal:function(component,event,helper){
        var cmpBack = component.find('Modalbackdrop');
        var cmpTarget = component.find('Modalbox');
        $A.util.removeClass(cmpBack,'slds-backdrop--open');
        $A.util.removeClass(cmpTarget, 'slds-fade-in-open');
        $A.get("e.force:closeQuickAction").fire();
        var homeEvent = $A.get("e.force:navigateToObjectHome");
        homeEvent.setParams({
            "scope": "Project__c"
        });
        homeEvent.fire();
    },
    openmodal: function(component,event,helper) {
        var cmpTarget = component.find('Modalbox');
        var cmpBack = component.find('Modalbackdrop');
        $A.util.addClass(cmpTarget, 'slds-fade-in-open');
        $A.util.addClass(cmpBack, 'slds-backdrop--open');
    }
})