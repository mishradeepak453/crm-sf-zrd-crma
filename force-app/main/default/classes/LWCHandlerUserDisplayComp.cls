/**
 * SF-1239 Projekt - Benutzer in zugew. Vertriebsgebieten
 * Handler class for LWC userDisplayComp that queries the users the lwc should display
 *
 * @author miriam.ida.tyroller@accenture.com
 *
 * @version 2023-10-13  miriam.ida.tyroller@accenture.com       creation
 */

public with sharing class LWCHandlerUserDisplayComp {

    /**
     * Queries all users views for a SobjectType a user has access to
     * 
     * @param currentObject object API name where lwc is place to find out for which Sobjecttype the users should be queried for
     * @param recordId object record ID of the record the lwc is placed on
     * 
     * @return list of users queried 
     */
    @AuraEnabled(cacheable=true)
    public static List<DataTableWrapper> queryUserData(String currentObject, String recordId){
        List<DataTableWrapper> response = new List<DataTableWrapper>();

        if(currentObject == '"Project__c"'){
            List<UserTerritory2Association> usTerrList = getUsersInProjectTerritory(recordId);

            if(usTerrList.size() > 0){
                for(UserTerritory2Association usTerrAssoc : usTerrList){
                    DataTableWrapper obj = new DataTableWrapper();
                    obj.userId = usTerrAssoc.Id;
                    obj.name = usTerrAssoc.User.Name;
                    obj.nameUrl = '/'+ usTerrAssoc.User.Id;
                    obj.email = usTerrAssoc.User.Email;
                    obj.role = usTerrAssoc.RoleInTerritory2;
                    obj.territory = usTerrAssoc.Territory2.Name;
                    response.add(obj);
                }
            }
        }

        return response;
    }

    /**
     * Queries all users for a project in its assigned project territories
     * 
     * @param recordId Id of the project
     * 
     * @return list of users in project territories 
     */
    @AuraEnabled(cacheable=true)
    public static List<UserTerritory2Association> getUsersInProjectTerritory(String recordId){
        List<UserTerritory2Association> usTerrList = new List<UserTerritory2Association>();
        
        List<Project_Territory__c> projTerrList = [SELECT Id, Project__c, Territory_ID__c FROM Project_Territory__c WHERE Project__c = : recordId];

        if(projTerrList.size() > 0){
            Set<String> terrIds = new Set<String>();

            for (Project_Territory__c projTerr : projTerrList){
                terrIds.add(projTerr.Territory_ID__c);
            }

            Map<Id,Territory2> territoriesById = new Map<Id,Territory2>([SELECT Id FROM Territory2 WHERE Core_External_ID__c IN : terrIds]);

            if(territoriesById.values().size() > 0){
                usTerrList = [SELECT Id, User.Id, User.Name, User.Email, Territory2.Name, toLabel(RoleInTerritory2) FROM UserTerritory2Association WHERE Territory2Id IN : territoriesById.keySet()];
            }
        }

        return usTerrList;
    }

    public class DataTableWrapper {
        @AuraEnabled
        public Id userId {get;set;}
        @AuraEnabled
        public String name {get;set;}
        @AuraEnabled
        public String nameUrl {get;set;}
        @AuraEnabled
        public String email {get;set;}
        @AuraEnabled
        public String role {get;set;}
        @AuraEnabled
        public String territory {get;set;}
    }
}