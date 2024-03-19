/**
* ManageJITUserUtility helps provides JIT functions to handle user ceration and update through various SSO methods like SAML, Open ID
*
* @version   1.0
* @since     2020-12-16
* @author    kian.parwini@accenture.com
*
* @version 2021-09-09  rene.pienkoss@accenture.com      SF-808: 1) Use new unique value from AD as FederationIdentifier instead of email address
*                                                               2) set User fields like Timezone, Language, ... only for new Users
*                                                               3) removed hard coded logic for group "ZRD-O-SF_SystemAdministrator"
* @version 2022-04-06  rene.pienkoss@accenture.com      1) Use Custom Setting (Suffix) to specify the domain name for new Users
*                                                       2) Use Custom Metadata to specify Default (Fallback) Profile and Permission Set Group
*/
public with sharing class ManageJITUserUtility {

    final static String DEFAULT_EMAIL_ENCODING  = 'ISO-8859-1';
    final static String DEFAULT_LANGUAGE        = 'de';
    final static String DEFAULT_LOCALE          = 'de_DE_EURO';
    final static String DEFAULT_TIMEZONE        = 'Europe/Berlin';

    // JIT provider key to Salesforce field mapping
    final static Map<String,Object> mapSAMLJITUserFields= (Map<String,Object>) JSON.deserializeUntyped(Label.SAML_JIT_Field_Map);
    
    /**
     * handleUserOnboarding process the user create/update request and call manage method 
     * @param mapInputParam to capture JIT parameter
     * @param userId to capture user Id in case of update. Otherwise, it'll be null
     * @return User records returned after operation
     */
    public static User handleUserOnboarding(String federationIdentifier, Map<String,Map<String,Object>> mapInputParam, Id userId, String assertion){
        System.debug('########## ManageJITUserUtility.handleUserOnboarding START');

        System.debug('########## mapInputParam.keySet(): ' + mapInputParam.keySet());
        System.debug('########## mapInputParam: ' + mapInputParam);
        System.debug('########## userId: ' + userId);
        System.debug('########## assertion: ' + assertion);

        User oUser;
        String sSSOMethod = new List<String>(mapInputParam.keyset()).get(0);
        switch on sSSOMethod {
            when 'SAML' {
                //In case of SAML based SSO
                oUser = manageUser(federationIdentifier, getFieldStringMapFromObjectMap(mapSAMLJITUserFields),mapInputParam.get('SAML'), extractGroupNamesFromAssertion(assertion), userId);                  
            }                                 
        }  
        
        System.debug('########## KPA: oUser: '+oUser);
        System.debug('########## ManageJITUserUtility.handleUserOnboarding END');                         
        return oUser;
    }

    /**
     * manageUser process the user create/update request using provided necessary field mapping
     * @param mapInputParam to capture JIT parameter
     * @param mapUserFields to capture JIT parameter to SF field API name mapping
     * @param lstGroups to capture role map key name
     * @param userId to capture user Id in case of update. Otherwise, it'll be null
     * @return User records returned after operation
     */
    public static User manageUser(String federationId, Map<String, String> mapUserFields, Map<String, Object> mapInputParam, List<String> lstGroups, Id userId) {
        System.debug('########## ManageJITUserUtility.manageUser START');
        System.debug('########## lstGroups: ' + lstGroups);

        Boolean preventLogin = false;
        User oUser = new User(Id=userId);
        List<PermissionSetAssignment> lstPSA = new List<PermissionSetAssignment>();
        List<String> permissionSetGroups = new List<String>();
        Map<Id,PermissionSetAssignment> mapExistingPSGA = new Map<Id,PermissionSetAssignment> ();

        // Copy values from attributes passed in SAML request to mapped fields on User
        for(String sKeyVar:mapUserFields.keySet()){
            if(mapInputParam.containsKey(sKeyVar)){
                oUser.put(mapUserFields.get(sKeyVar), mapInputParam.get(sKeyVar));
            }
        }

        // 1. Fall User hat GRUPPEN im AD hinterlegt
        // Login nach Salesforce darf erfolgen
        if ( ! lstGroups.isEmpty()) {
            System.debug('########## USER HAT GRUPPEN-ZUORDNUNG');

            // Gruppennamen im AD können "-" oder "_". Transformiere IMMER zu "_" wegen Developernamen im SF
            List<String> groupNamesAdjusted = new List<String>();
            for(String groupName : lstGroups){
                String tmpString = groupName.replace('-','_');
                groupNamesAdjusted.add(tmpString);
            }

            List<SSO_User_Maping_Config__mdt> oSSOConfig  =   [SELECT Id,
                                                                    DeveloperName,
                                                                    Salesforce_Permission_Set_Group__c,
                                                                    Salesforce_Profile_Name__c,
                                                                    Salesforce_Role_Name__c
                                                                FROM SSO_User_Maping_Config__mdt 
                                                                WHERE DeveloperName IN :groupNamesAdjusted];

            // 1. Fall: Für die Gruppen im AD gibt es kein passendes Mapping im SF
            // Assigne User Standard-Zeppelin-Profil und Permission-Set-Group: ZR_Nur Leserechte
            if(oSSOConfig.isEmpty()){
                System.debug('########## ES EXISTIERT KEIN MAPPING');

                // get default mapping
                SSO_User_Maping_Config__mdt defaultSSOConf;
                for (SSO_User_Maping_Config__mdt ssoConf : SSO_User_Maping_Config__mdt.getAll().values()) {
                    if (ssoConf.Is_Default__c) {
                        defaultSSOConf = ssoConf;
                        break;
                    }
                }

                if (defaultSSOConf != null && String.isNotBlank(defaultSSOConf.Salesforce_Profile_Name__c)) {
                    // Profil
                    oUser.ProfileId = [SELECT Id FROM Profile WHERE Name = :defaultSSOConf.Salesforce_Profile_Name__c].Id;

                    // Permission-Set-Group
                    if (String.isNotBlank(defaultSSOConf.Salesforce_Permission_Set_Group__c)) {
                        permissionSetGroups.add(defaultSSOConf.Salesforce_Permission_Set_Group__c);
                    }
                }
                else {
                    throw new SAMLJITHandler.JitException('Missing Profile Mappings');
                }
            }
            // 2.Fall: Für die Gruppen im AD gibt es passende Mappings im SF
            // Assigne User Standard-Zeppelin-Profil und Permission-Set-Groups addieren sich aus allen Mappings
            else{
                System.debug('########## ES EXISTIEREN MAPPINGS (>=1): ' + oSSOConfig);
                // Es gibt nur ein Standard-Zeppelin-Profil für alle User, deswegen macht es keinen Unterschied ob es 1 oder mehrere Mappings im SF gibt

                // Profil
                System.debug('########## Salesforce_Profile_Name__c: ' + oSSOConfig[0].Salesforce_Profile_Name__c);
                oUser.ProfileId = [SELECT Id FROM Profile WHERE Name = :oSSOConfig[0].Salesforce_Profile_Name__c].Id;

                // Rolle
                if(String.isNotEmpty(oSSOConfig[0].Salesforce_Role_Name__c)){
                    oUser.userRoleId = [SELECT Id FROM UserRole WHERE DeveloperName =: oSSOConfig[0].Salesforce_Role_Name__c].Id;  
                }
                else{
                    // THIS IS COMMENTED BECAUSE WE DONT WANT TO OVERWRITE THE MANUALLY SET ROLE
                    //oUser.userRoleId    =   null;
                }

                // Permission-Set-Groups: Addieren PSGs aus allen Mappings. Kann mehrere pro Mapping geben, durch "," separariert.
                for(SSO_User_Maping_Config__mdt actualMapping : oSSOConfig){
                    System.debug(' ActualMAPPING '+actualMapping);
                    if(String.isNotBlank(actualMapping.Salesforce_Permission_Set_Group__c)){
                        System.debug(' NOTBLANK PSG ');
                        permissionSetGroups.addAll(actualMapping.Salesforce_Permission_Set_Group__c.split(','));
                    }
                }
            }
            oUser.isActive=true;

        } else{
            // 2. Fall User hat KEINE GRUPPEN im AD hinterlegt
            // Login nach Salesforce darf nicht erfolgen
            System.debug('########## USER HAT KEINE GRUPPEN IM AD');
            preventLogin = true;
            // user war schonmal aktiv in SF
            if(String.isNotEmpty(oUser.Id)){
                System.debug('########## USER HAT KEINE GRUPPEN IM AD WAR ABER SCHONMAL AKTIV');
                oUser.isActive=false;
            }
            else{
                // user ist komplett neu
                System.debug('########## USER HAT KEINE GRUPPEN IM AD UND IST KOMPLETT NEU IM SF');
                return oUser;
            }
        }

        System.debug('########## preventLogin: ' + preventLogin);

        if(!preventLogin){
            System.debug('########## oUser before: ' + oUser);

            // set fields only for new Users
            if (String.isEmpty(oUser.Id)) {
                // Default fields
                if(String.isEmpty(oUser.EmailEncodingKey)){
                    oUser.EmailEncodingKey=DEFAULT_EMAIL_ENCODING;
                }
                if(String.isEmpty(oUser.LanguageLocaleKey)){
                    oUser.LanguageLocaleKey=DEFAULT_LANGUAGE;
                }
                if(String.isEmpty(oUser.localesidkey)){
                    oUser.localesidkey=DEFAULT_LOCALE;
                }
                if(String.isEmpty(oUser.TimeZoneSidKey)){
                    oUser.TimeZoneSidKey=DEFAULT_TIMEZONE; 
                }
                // set FederationIdentifier only for new Users
                if(String.isEmpty(oUser.FederationIdentifier)){
                    oUser.FederationIdentifier=federationId;
                }  
                if(String.isEmpty(oUser.UserName)){
                    Map<String, UserName_Suffix__c> suffixConf = UserName_Suffix__c.getall();
                    String userSuffix;
                    System.debug('########## suffixConf: ' + suffixConf);

                    if ( ! suffixConf.isEmpty()) {
                        userSuffix = suffixConf.values()[0].Name;
                    }
                    else {
                        throw new SAMLJITHandler.JitException('Missing configuration for Username');
                    }

                    System.debug('########## oUser.Email: ' + oUser.Email);
                    System.debug('########## userSuffix: ' + userSuffix);
                    oUser.UserName = oUser.Email.subStringBefore('@')+'@'+userSuffix;
                }
                if(String.isEmpty(oUser.CommunityNickname)){
                    oUser.CommunityNickname=(oUser.FirstName+ oUser.LastName).subString(0,4) + randomNumberGenerator(4);
                }
                if(String.isEmpty(oUser.Alias)){
                    oUser.Alias=oUser.CommunityNickname;
                }
            }

            System.debug('########## oUser after: ' + oUser);
        
            if(String.isNotEmpty(oUser.Id)){
                System.debug('########## USER UPDATE');
                update oUser;
            }
            else{
                System.debug('########## USER INSERT');
                insert oUser; 
            }

            // Permission-Set-Group-Assignments
            if(!Test.isRunningTest()){
                // 1. Schritt: Suche nach existierenden User-PSG-Assignments
                for(PermissionSetAssignment actualPSGA : [SELECT Id, PermissionSet.Name, PermissionSet.PermissionSetGroupId, AssigneeId from PermissionSetAssignment 
                                                        WHERE PermissionSet.PermissionSetGroupId != NULL AND AssigneeId=:oUser.Id]){
                    mapExistingPSGA.put(actualPSGA.PermissionSet.PermissionSetGroupId, actualPSGA);
                }

                System.debug('########## USER EXISTING PSGA BEFORE '+mapExistingPSGA);

                // 2. Schritt: Neue PSGA hinzufügen
                if(!permissionSetGroups.isEmpty()){

                    System.debug('########## KPA permissionSetGroups '+permissionSetGroups);

                    // hole alle relevanten PSG
                    Map<Id,PermissionSet> mapRequiredPermissionSet = new Map<Id,PermissionSet> ([SELECT Id, Name, PermissionSetGroupId FROM PermissionSet WHERE Name IN :permissionSetGroups]);

                    System.debug('########## KPA mapRequiredPermissionSet '+mapRequiredPermissionSet);

                    for(Id perIdVar: mapRequiredPermissionSet.keySet()){
                        System.debug('########## KPA current ID '+perIdVar);
                        System.debug('########## KPA mapRequiredPermissionSet.get(perIdVar).PermissionSetGroupId) '+mapRequiredPermissionSet.get(perIdVar).PermissionSetGroupId);
                        if(!mapExistingPSGA.containsKey(mapRequiredPermissionSet.get(perIdVar).PermissionSetGroupId)){
                            System.debug('########## KPA TRUE');
                            // Falls neue PSGA erkannt werden, zur Liste hinzufügen und später INSERTEN
                            lstPSA.add(new PermissionSetAssignment(PermissionSetGroupId = mapRequiredPermissionSet.get(perIdVar).PermissionSetGroupId, AssigneeId = oUser.Id));
                        }
                        else if(mapExistingPSGA.containsKey(mapRequiredPermissionSet.get(perIdVar).PermissionSetGroupId)){
                            System.debug('########## KPA ELSE IF');
                            // PSGA die zu entfernen sind
                            mapExistingPSGA.remove(mapRequiredPermissionSet.get(perIdVar).PermissionSetGroupId); 
                        }
                    }
                }

                System.debug('########## KPA lstPSA '+lstPSA);
                System.debug('########## KPA mapExistingPSGA AFTER '+mapExistingPSGA);

                // Falls es neue PSGAs gibt    
                if(lstPSA.size()>0){
                    insert lstPSA;
                }

                // PSGAs zum entfernen 
                if(mapExistingPSGA.size()>0 ) {
                    delete mapExistingPSGA.values();
                }
            }
        }

        System.debug('########## ManageJITUserUtility.manageUser END'); 
        return oUser;
    }

    /**
     * randomNumberGenerator process random number generation
     * @param iLength to provide random number length
     * @return String format of generated random Number
     */
    private static String randomNumberGenerator(Integer iLength){
        String str = string.valueof(Math.abs(Crypto.getRandomLong()));
        String sRandomNumber = str.substring(0, iLength);
        return sRandomNumber;
    }

    private static Map<String,String> getFieldStringMapFromObjectMap(Map<String,Object> mapObj){
        Map<String,String> mapStr=new Map<String,String>();
        for(String sKeyVar: mapObj.keySet()){
            if(mapObj.get(sKeyVar)!=null)
                mapStr.put(sKeyVar,String.valueOf(mapObj.get(sKeyVar)));
        }
       return  mapStr;
    }

    private static List<String> extractGroupNamesFromAssertion(String assertion){
        List<String> groups = new List<String>();
        if(String.isNotBlank(assertion)){
            String assertionString = EncodingUtil.base64Decode(assertion).toString();
            String findString = '<Attribute Name="http://schemas.microsoft.com/ws/2008/06/identity/claims/groups">';
    
            if(assertionString.contains(findString)){
                Integer idx = assertionString.indexOf(findString)+findString.length();
                groups = assertionString.substring(idx).split('</Attribute>')[0].remove('<AttributeValue>').split('</AttributeValue>');
            }
        }
        return groups;
    }

}