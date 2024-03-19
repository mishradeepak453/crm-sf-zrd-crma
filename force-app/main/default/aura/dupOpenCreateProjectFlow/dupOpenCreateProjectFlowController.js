({
   openFlow: function(component, event) {
      var parentRecordId;
      var params = event.getParam('arguments');
      if (params) {
         parentRecordId = params.parentRecordId;
         const flow = component.find("flow");
         if(parentRecordId != null) {
            var inputVariables = [
               {
                  name : 'parentRecordId',
                  type : 'String',
                  value : parentRecordId
               }
            ];
            flow.startFlow("Create_Project_Screen_Flow",inputVariables);
         } else {
            flow.startFlow("Create_Project_Screen_Flow");
         }
      }
  },
   doInit: function(component, event, helper){
      var parentRecordId = component.get("v.parentRecordId")
      const flow = component.find("flow");
      if(parentRecordId != null) {
         var inputVariables = [
            {
               recordId : 'parentRecordId',
               type : 'String',
               value : parentRecordId
            }
         ];

         flow.startFlow("Create_Project_Screen_Flow",inputVariables);
      } else {
         flow.startFlow("Create_Project_Screen_Flow");
      }

   },
   handleStatusChange : function (component, event) {
      if(event.getParam("status") === "FINISHED") {
         var outputVariables = event.getParam("outputVariables");
         var outputVar;
         for(var i = 0; i < outputVariables.length; i++) {
            outputVar = outputVariables[i];
            if(outputVar.name === "recordId" && outputVar.value === null) {
               var homeEvent = $A.get("e.force:navigateToObjectHome");
               homeEvent.setParams({
                  "scope": "Project__c"
               });
               homeEvent.fire();
            } else if(outputVar.name === "recordId" && outputVar.value !== null) {
               var urlEvent = $A.get("e.force:navigateToSObject");
               urlEvent.setParams({
                  "recordId": outputVar.value,
                  "isredirect": "true"
               });
               urlEvent.fire();
            }
         }
      }
   }
});