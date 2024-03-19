/**
 * SF-1134 Anzeige von Projekten und Accounts auf einer grafischen Karte
 * Handler class for LWC mapComp + mapListViewScreen that creates the map markers placed on the lwc map
 *
 * @author miriam.ida.tyroller@accenture.com
 *
 * @version 2023-10-04  miriam.ida.tyroller@accenture.com       creation
 */

public without sharing class LWCHandlerMapComp {

    /**
     * Method that queries all records currently in a list view and parses them into map markers for the lwc map to use
     * 
     * @param listViewId Id of the list view
     * @param currentUrl Url from where the lwc is placed on to determine the type of SObject to be queried
     * 
     * @return list of map markers parsed from the list view
     */
    @AuraEnabled(cacheable=true)
    public static List<MapMarker> queryMapData(String listViewId, String currentUrl){
        List<MapMarker> mapMarkerData = new List<MapMarker>();
        if(currentUrl.contains('Account')){
            List<Account> accountData = queryAccountData(listViewId);

            Integer counter = 0;

            for (Account acc : accountData){
                if(acc.BillingCity != null){
                    MapMarker mapMark = new MapMarker();
                    mapMark.location = new LocationClass();
                    mapMark.location.City = acc.BillingCity;
                    mapMark.location.Country = acc.BillingCountryCode;
                    mapMark.location.PostalCode = acc.BillingPostalCode;
                    mapMark.location.State = acc.BillingStateCode;
                    mapMark.location.Street = acc.BillingStreet;
                    mapMark.value = String.valueOf(counter);
                    mapMark.title = acc.Name;
                    mapMark.description = '';
                    //create description out of Name2 + Project Address, but only if fields have values
                    if(acc.Name2__c != null){
                        mapMark.description = mapMark.description + acc.Name2__c + '<br/><br/>';
                    }
                    if(acc.BillingStreet != null){
                        mapMark.description = mapMark.description + acc.BillingStreet;
                    }
                    if(acc.BillingPostalCode != null){
                        mapMark.description = mapMark.description + ', ' + acc.BillingPostalCode + ' ';
                    }
                    mapMark.description = mapMark.description + acc.BillingCity;
                    if(acc.BillingStateCode != null){
                        mapMark.description = mapMark.description + ', ' + acc.BillingStateCode;
                    }
                    if(acc.BillingCountryCode != null){
                        mapMark.description = mapMark.description + ', ' + acc.BillingCountryCode;
                    }
                    
                    mapMark.icon = 'standard:account';
                    mapMarkerData.add(mapMark);
                }
            }
        }
        else if(currentUrl.contains('Project')){
            List<Project__c> projectData = queryProjectData(listViewId);

            Integer counter = 0;

            for (Project__c proj : projectData){
                if(proj.Project_Address__City__s != null){
                    MapMarker mapMark = new MapMarker();
                    mapMark.location = new LocationClass();
                    mapMark.location.City = proj.Project_Address__City__s;
                    mapMark.location.Country = proj.Project_Address__CountryCode__s;
                    mapMark.location.PostalCode = proj.Project_Address__PostalCode__s;
                    mapMark.location.State = proj.Project_Address__StateCode__s;
                    mapMark.location.Street = proj.Project_Address__Street__s;
                    mapMark.value = String.valueOf(counter);
                    mapMark.title = proj.Name;
                    mapMark.description = '';
                    if(proj.Total_Volume__c != null){
                        mapMark.description = mapMark.description + proj.Total_Volume__c +  '€' + '<br/><br/>';
                    }
                    if(proj.Project_Address__Street__s != null){
                        mapMark.description = mapMark.description + proj.Project_Address__Street__s;
                    }
                    if(proj.Project_Address__PostalCode__s != null){
                        mapMark.description = mapMark.description + ', ' + proj.Project_Address__PostalCode__s + ' ';
                    }
                    mapMark.description = mapMark.description + proj.Project_Address__City__s;
                    if(proj.Project_Address__StateCode__s != null){
                        mapMark.description = mapMark.description + ', ' + proj.Project_Address__StateCode__s;
                    }
                    if(proj.Project_Address__CountryCode__s != null){
                        mapMark.description = mapMark.description + ', ' + proj.Project_Address__CountryCode__s;
                    }
                    mapMark.icon = 'standard:account';
                    mapMarkerData.add(mapMark);
                }
            }
        }

        return mapMarkerData;
    }

    /**
     * Queries all project data fitting the query of a list view, extending the list view query by the fields
     * necessary to create map markers
     * 
     * @param listViewId Id of list view for projects
     * 
     * @return list of project__c data queried
     */
    @AuraEnabled(cacheable=true)
    public static List<Project__c> queryProjectData(String listViewId){
        String queryString = getListViewQuery(listViewId, 'Project__c');

        //adjust query string to always include relevant fields
        if(!queryString.contains('Project_Address__City__s,') 
            && !queryString.contains('Project_Address__City__s FROM')){
            Integer s = queryString.indexOf('SELECT') + 'SELECT'.length();
            queryString = 'SELECT Project_Address__City__s, ' + queryString.substring(s);
        }

        if(!queryString.contains('Project_Address__CountryCode__s,') 
        && !queryString.contains('Project_Address__CountryCode__s FROM')
        && !queryString.contains('toLabel(Project_Address__CountryCode__s),')
        && !queryString.contains('toLabel(Project_Address__CountryCode__s) FROM')){
            Integer s = queryString.indexOf('SELECT') + 'SELECT'.length();
            queryString = 'SELECT Project_Address__CountryCode__s, ' + queryString.substring(s);
        }

        if(!queryString.contains('Project_Address__PostalCode__s,') 
        && !queryString.contains('Project_Address__PostalCode__s FROM')){
            Integer s = queryString.indexOf('SELECT') + 'SELECT'.length();
            queryString = 'SELECT Project_Address__PostalCode__s, ' + queryString.substring(s);
        }

        if(!queryString.contains('Project_Address__Street__s,') 
        && !queryString.contains('Project_Address__Street__s FROM')){
            Integer s = queryString.indexOf('SELECT') + 'SELECT'.length();
            queryString = 'SELECT Project_Address__Street__s, ' + queryString.substring(s);
        }

        if(!queryString.contains('Project_Address__StateCode__s,') 
        && !queryString.contains('Project_Address__StateCode__s FROM')
        && !queryString.contains('toLabel(Project_Address__StateCode__s),')
        && !queryString.contains('toLabel(Project_Address__StateCode__s) FROM')){
            Integer s = queryString.indexOf('SELECT') + 'SELECT'.length();
            queryString = 'SELECT Project_Address__StateCode__s, ' + queryString.substring(s);
        }

        if(!queryString.contains('Total_Volume__c,') 
        && !queryString.contains('Total_Volume__c FROM')){
            Integer s = queryString.indexOf('SELECT') + 'SELECT'.length();
            queryString = 'SELECT Total_Volume__c, ' + queryString.substring(s);   
        }

        if(!queryString.contains('Name,') 
        && !queryString.contains('Name FROM')){
            Integer s = queryString.indexOf('SELECT') + 'SELECT'.length();
            queryString = 'SELECT Name, ' + queryString.substring(s);   
        }

        System.debug('queryString: ' + queryString);

        List<Project__c> projectData = Database.query(queryString);
        
        return projectData;
    }

    /**
     * Queries all account data fitting the query of a list view, extending the list view query by the fields
     * necessary to create map markers
     * 
     * @param listViewId Id of list view for accounts
     * 
     * @return list of account data queried
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> queryAccountData(String listViewId){
        String queryString = getListViewQuery(listViewId, 'Account');

        //adjust query string to always include relevant fields
        if(!queryString.contains('BillingCity,') 
            && !queryString.contains('BillingCity FROM') ){
                Integer s = queryString.indexOf('SELECT') + 'SELECT'.length();
                queryString = 'SELECT BillingCity, ' + queryString.substring(s);
        }

        if(!queryString.contains('BillingCountryCode,') 
            && !queryString.contains('BillingCountryCode FROM') 
            && !queryString.contains('toLabel(BillingCountryCode),')
            && !queryString.contains('toLabel(BillingCountryCode) FROM')){    
                Integer s = queryString.indexOf('SELECT') + 'SELECT'.length();
                queryString = 'SELECT BillingCountryCode, ' + queryString.substring(s);
        }

        if(!queryString.contains('BillingPostalCode,') 
            && !queryString.contains('BillingPostalCode FROM') ){    
                Integer s = queryString.indexOf('SELECT') + 'SELECT'.length();
                queryString = 'SELECT BillingPostalCode, ' + queryString.substring(s);
        }

        if(!queryString.contains('BillingStreet,') 
            && !queryString.contains('BillingStreet FROM')){    
                Integer s = queryString.indexOf('SELECT') + 'SELECT'.length();
                queryString = 'SELECT BillingStreet, ' + queryString.substring(s);
        }

        if(!queryString.contains('BillingStateCode,') 
            && !queryString.contains('BillingStateCode FROM') 
            && !queryString.contains('toLabel(BillingStateCode),')
            && !queryString.contains('toLabel(BillingStateCode) FROM')){    
                Integer s = queryString.indexOf('SELECT') + 'SELECT'.length();
                queryString = 'SELECT BillingStateCode, ' + queryString.substring(s);
        }

        if(!queryString.contains('Name,') 
            && !queryString.contains('Name FROM')){    
                Integer s = queryString.indexOf('SELECT') + 'SELECT'.length();
                queryString = 'SELECT Name, ' + queryString.substring(s);
        }

        if(!queryString.contains('Name2__c,') 
            && !queryString.contains('Name2__c FROM')){    
                Integer s = queryString.indexOf('SELECT') + 'SELECT'.length();
                queryString = 'SELECT Name2__c, ' + queryString.substring(s);
        } 

        System.debug('queryString: ' + queryString);
        List<Account> accountData = Database.query(queryString);

        return accountData;
    }

    /**
     * Queries all list views for a SobjectType a user has access to
     * 
     * @param currentUrl url where lwc is place to find out for which Sobjecttype the list views should be queried
     * 
     * @return list of list views queried 
     */
    @AuraEnabled(cacheable=true)
    public static List<ListView> queryUserListViews(String currentUrl){
        List<ListView> listViewData = new List<ListView>();
        if(currentUrl.contains('Project')){
            listViewData = [SELECT Id, Name FROM ListView WHERE SobjectType = 'Project__c'];
        }
        else if(currentUrl.contains('Account')){
            listViewData = [SELECT Id, Name FROM ListView WHERE SobjectType = 'Account'];
        }
        return listViewData;
    }

    /**
     * Call out method to get the query string a list view uses to get the records that are part of a list view
     * 
     * @param filterId Id of the list view
     * @param objectName type of SObject the list view belongs to
     * 
     * @return queryString from the list view
     */
    public static String getListViewQuery(String filterId, String objectName) {
        String queryString = '';
        HttpRequest req = new HttpRequest();
        String baseUrl = URL.getSalesforceBaseUrl().toExternalForm();
        String endPoinURL = baseUrl+'/services/data/v59.0/sobjects/'+ objectName +'/listviews/'+ filterId +'/describe';
        System.debug('endPoinURL: ' + endPoinURL);
        req.setEndpoint(endPoinURL);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + getSessionIdFromVFPage(Page.GetSessionId));
        Http http = new Http();
        HttpResponse response = new HttpResponse();
        if (!Test.isRunningTest()) {
            response = http.send(req);
        }
        else {
            response.setStatusCode(200);
            if(objectName == 'Account'){
                response.setBody('{"columns":[{"ascendingLabel":"Z-A","descendingLabel":"A-Z","fieldNameOrPath":"Name","hidden":false,"label":"Account Name","searchable":true,"selectListItem":"Name","sortDirection":"ascending","sortIndex":0,"sortable":true,"type":"string"},{"ascendingLabel":"Low to High","descendingLabel":"High to Low","fieldNameOrPath":"BillingStateCode","hidden":false,"label":"Company State/Province","searchable":true,"selectListItem":"toLabel(BillingStateCode)","sortDirection":null,"sortIndex":null,"sortable":true,"type":"picklist"},{"ascendingLabel":"9-0","descendingLabel":"0-9","fieldNameOrPath":"Phone","hidden":false,"label":"Phone","searchable":true,"selectListItem":'+
                '"Phone","sortDirection":null,"sortIndex":null,"sortable":true,"type":"phone"},{"ascendingLabel":"Low to High","descendingLabel":"High to Low","fieldNameOrPath":"Type","hidden":false,"label":"Type","searchable":true,"selectListItem":"toLabel(Type)","sortDirection":null,"sortIndex":null,"sortable":true,"type":"picklist"},{"ascendingLabel":"Z-A","descendingLabel":"A-Z","fieldNameOrPath":"Owner.Alias","hidden":false,"label":"Account Owner Alias","searchable":false,"selectListItem":"Owner.Alias","sortDirection":null,"sortIndex":null,"sortable":true,"type":"string"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"Id","hidden":true,"label":"Account ID",'+
                '"searchable":false,"selectListItem":"Id","sortDirection":null,"sortIndex":null,"sortable":false,"type":"id"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"RecordTypeId","hidden":true,"label":"Record Type ID","searchable":false,"selectListItem":"RecordTypeId","sortDirection":null,"sortIndex":null,"sortable":false,"type":"reference"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"CreatedDate","hidden":true,"label":"Created Date","searchable":false,"selectListItem":"CreatedDate","sortDirection":null,"sortIndex":null,"sortable":false,"type":"datetime"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"LastModifiedDate",'+
                '"hidden":true,"label":"Last Modified Date","searchable":false,"selectListItem":"LastModifiedDate","sortDirection":null,"sortIndex":null,"sortable":false,"type":"datetime"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"SystemModstamp","hidden":true,"label":"System Modstamp","searchable":false,"selectListItem":"SystemModstamp","sortDirection":null,"sortIndex":null,"sortable":false,"type":"datetime"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"Owner.Id","hidden":true,"label":"User ID","searchable":false,"selectListItem":"Owner.Id","sortDirection":null,"sortIndex":null,"sortable":false,"type":"id"},{"ascendingLabel":null,"descendingLabel":null,'+
                '"fieldNameOrPath":"OwnerId","hidden":true,"label":"Owner ID","searchable":false,"selectListItem":"OwnerId","sortDirection":null,"sortIndex":null,"sortable":false,"type":"reference"}],"id":"00B9E00000579mv","orderBy":[{"fieldNameOrPath":"Name","nullsPosition":"first","sortDirection":"ascending"},{"fieldNameOrPath":"Id","nullsPosition":"first","sortDirection":"ascending"}],"query":"SELECT Id FROM Account ORDER BY Name ASC NULLS FIRST, Id ASC NULLS FIRST","relatedEntityId":null,"scope":"mine","scopeEntityId":null,"sobjectType":"Account","whereCondition":{"conditions":[],"conjunction":"and"}}');
            } else if (objectName == 'Project__c'){
                response.setBody('{"columns":[{"ascendingLabel":"Z-A","descendingLabel":"A-Z","fieldNameOrPath":"Name","hidden":false,"label":"Project Name","searchable":true,"selectListItem":"Name","sortDirection":"ascending","sortIndex":0,"sortable":true,"type":"string"},{"ascendingLabel":"Z-A","descendingLabel":"A-Z","fieldNameOrPath":"Project_Address__City__s","hidden":false,"label":"Project Address (City)","searchable":false,"selectListItem":"Project_Address__City__s","sortDirection":null,"sortIndex":null,"sortable":true,"type":"string"},{"ascendingLabel":"Z-A","descendingLabel":"A-Z","fieldNameOrPath":"Project_Address__Street__s","hidden":false,"label":"Project Address (Street)",'+
                '"searchable":false,"selectListItem":"Project_Address__Street__s","sortDirection":null,"sortIndex":null,"sortable":true,"type":"textarea"},{"ascendingLabel":"Low to High","descendingLabel":"High to Low","fieldNameOrPath":"Project_Address__StateCode__s","hidden":false,"label":"Project Address (State/Province)","searchable":false,"selectListItem":"toLabel(Project_Address__StateCode__s)","sortDirection":null,"sortIndex":null,"sortable":true,"type":"picklist"},{"ascendingLabel":"Z-A","descendingLabel":"A-Z","fieldNameOrPath":"Project_Address__PostalCode__s","hidden":false,"label":"Project Address (ZIP/Postal Code)","searchable":false,"selectListItem":"Project_Address__PostalCode__s",'+
                '"sortDirection":null,"sortIndex":null,"sortable":true,"type":"string"},{"ascendingLabel":"Low to High","descendingLabel":"High to Low","fieldNameOrPath":"Project_Address__CountryCode__s","hidden":false,"label":"Project Address (Country/Territory)","searchable":false,"selectListItem":"toLabel(Project_Address__CountryCode__s)","sortDirection":null,"sortIndex":null,"sortable":true,"type":"picklist"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"Id","hidden":true,"label":"Record ID","searchable":false,"selectListItem":"Id","sortDirection":null,"sortIndex":null,"sortable":false,"type":"id"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"CreatedDate",'+
                '"hidden":true,"label":"Created Date","searchable":false,"selectListItem":"CreatedDate","sortDirection":null,"sortIndex":null,"sortable":false,"type":"datetime"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"LastModifiedDate","hidden":true,"label":"Last Modified Date","searchable":false,"selectListItem":"LastModifiedDate","sortDirection":null,"sortIndex":null,"sortable":false,"type":"datetime"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"SystemModstamp","hidden":true,"label":"System Modstamp","searchable":false,"selectListItem":"SystemModstamp","sortDirection":null,"sortIndex":null,"sortable":false,"type":"datetime"}],"id":"00B9E00000579Gz",'+
                '"orderBy":[{"fieldNameOrPath":"Name","nullsPosition":"first","sortDirection":"ascending"},{"fieldNameOrPath":"Id","nullsPosition":"first","sortDirection":"ascending"}],"query":"SELECT Id FROM Project__c ORDER BY Name ASC NULLS FIRST, Id ASC NULLS FIRST","relatedEntityId":null,"scope":"mine","scopeEntityId":null,"sobjectType":"Project__c","whereCondition":{"conditions":[],"conjunction":"and"}}');
            }
        }
        System.debug('response: ' + response.getBody());
        if( response.getStatusCode() == 200 ) {
            Map<String, Object> tokenResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            queryString = (String) tokenResponse.get('query');
            System.debug(queryString);
        }

        return queryString;
    }

    /**
     * Helper method to get the current session id from a helper vf page (work around to get the current session id)
     * 
     * @param visualforcePage name of helper vf page
     * 
     * @return current session id
     */
    public static String getSessionIdFromVFPage(PageReference visualforcePage){
        String content = '';
        if (!Test.isRunningTest()) {
            content = visualforcePage.getContent().toString();
        }
        else{
            content = 'Start_Of_Session_Id12345678End_Of_Session_Id';
        }

        Integer s = content.indexOf('Start_Of_Session_Id') + 'Start_Of_Session_Id'.length(),
                e = content.indexOf('End_Of_Session_Id');
        return content.substring(s, e);
    }

    public class MapMarker{
        @AuraEnabled public LocationClass location;
        @AuraEnabled public String value;
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public String icon;
    }

    public class LocationClass{
        @AuraEnabled public String City;
        @AuraEnabled public String Country;
        @AuraEnabled public String PostalCode;
        @AuraEnabled public String State;
        @AuraEnabled public String Street; 
    }
}