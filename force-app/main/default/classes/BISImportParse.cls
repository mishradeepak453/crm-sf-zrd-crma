/**
 * Helper class to parse Project Import and convert it for further processing.
 * 
 * @author  rene.pienkoss@accenture.com
 * 
 * @version 2021-12-02  rene.pienkoss@accenture.com     creation
 * @version 2022-05-05  rene.pienkoss@accenture.com     added property to count items received in JSON
 * @version 2023-02-13  miriam.ida.tyroller@accenture.com added JSON parse for infobau response
 * @version 2023-09-01  miriam.ida.tyroller@accenture.com added parse of involved accounts
 * @version 2023-10-24  isabella.moos@accenture.com     set cleansed address field values for ibau
 */
public class BISImportParse {
    
    public static final String CLASSNAME = 'BISImportParse';

    // separator to be used between different description values
    private static final String descSeparator = '<br>----------<br>';

    private static Set<String> projectConstructionProgressValues;

    private static Map<String, BIS_AccountRole_Mapping__mdt> accountRoleMappingRecordsByBISValue;

    // get supported picklist values for Project_Construction_Progress__c field
    public static Set<String> getProjectConstructionProgressValues {
        get {
            if (projectConstructionProgressValues == null) {
                projectConstructionProgressValues = new Set<String>();
                for (Schema.PicklistEntry pe : Project__c.Project_Construction_Progress__c.getDescribe().getPicklistValues()) { 
                    projectConstructionProgressValues.add(pe.getValue());
                }
            }
            return projectConstructionProgressValues;
        }
    }

    // get supported picklist values for account Roles field
    public static Map<String, BIS_AccountRole_Mapping__mdt> getAccountRoleMappingRecordsByBISValue {
        get {
            if (accountRoleMappingRecordsByBISValue == null) {
                accountRoleMappingRecordsByBISValue = new Map<String, BIS_AccountRole_Mapping__mdt>();
                List<BIS_AccountRole_Mapping__mdt> accountRoleMappingRecords = [SELECT Id, BIS_Value__c, SF_Picklist_Value__c FROM BIS_AccountRole_Mapping__mdt];

                if (!accountRoleMappingRecords.isEmpty()) {
                    accountRoleMappingRecordsByBISValue = (Map<String, BIS_AccountRole_Mapping__mdt>) UTLCommons.mapByStringField(
                        accountRoleMappingRecords,
                        BIS_AccountRole_Mapping__mdt.BIS_Value__c
                    );
                }

            }
            return accountRoleMappingRecordsByBISValue;
        }
    }


    /**
     * Parses the XML string and returns all relevant 
     * project data for further processing.
     * 
     * @param   context     current import context (e.g. infobau or ibau)
     * @param   projectXML  the project XML string containing project data
     * 
     * @return  list of BISProjectImport.BISProject containing all relevant project data from XML
     */
    public static ParseResult parseAndConvertProjectXML(String context, String projectXML) {
        System.debug('########## RP parseAndConvertProjectXML: ' + context);
        ParseResult pr = new ParseResult();

        Dom.Document doc = new Dom.Document();
        doc.load(projectXML);
        Dom.XmlNode xnResult = doc.getRootElement();
        
        // get total amount of project items to be imported
        pr.total = Integer.valueOf(xnResult.getAttribute('total', null));

        Dom.XmlNode xnItems = xnResult.getChildElement('items', null);
        List<Dom.XmlNode> xnItemList = xnItems.getChildElements();

        pr.projectItemsCount = xnItemList.size();
        Map<String,InvolvedAccount> involvedAccountsByAccountExternalId = new Map<String,InvolvedAccount>();

        Set<String> skippedAccRoles = new Set<String>();

        // parse projects
        for (Dom.XmlNode xnItem : xnItemList) {
            Dom.XmlNode xnProject = xnItem.getChildElement('project', null);
            
            try {
                BISProjectImport.BISProject projectData;
                if (context == BISProjectImport.CONTEXT_IBAU_DE) {
                    projectData = parseIbauProject(xnProject);
                    skippedAccRoles.addAll(projectData.skippedAccountRoles);
                }
                else if (context == BISProjectImport.CONTEXT_INFOBAU) {
                    //projectData = parseInfobauProject(xnProject);
                }

                if (projectData != null) {
                    if (!projectData.doDelete) {
                        pr.projects.add(projectData);
                        pr.projectExternalIds.add((String) projectData.project.get('External_ID__c'));
                        for(InvolvedAccount invAcc : projectData.involvedAccounts){
                            involvedAccountsByAccountExternalId.put(invAcc.accountId, invAcc);
                        }
                        pr.involvedAccountsbyAccountExternalId = involvedAccountsByAccountExternalId;
                    }
                    else {
                        pr.projectExtIdToDelete.add((String) projectData.project.get('External_ID__c'));
                    }
                }
            }
            catch (Exception e) {
                System.debug('########## RP Exception: ' + e.getMessage());
                Core_Error_Log__c errorLog = UTLErrorLog.createErrorLogRecord(CLASSNAME, e, 'Error while parsing project XML: ' + e.getMessage(), null, BISProjectImport.SOURCESYSTEM, true);
                pr.errorLogs.put(errorLog.Core_Checksum__c, errorLog);
            }
        }

        System.debug('Skipped Account Roles: ');
        for(String s : skippedAccRoles){
            System.debug(s);
        }
        

        return pr;
    }

    /**
     * Parse XML of ibau projects
     */
    public static BISProjectImport.BISProject parseIbauProject(Dom.XmlNode xnProject) {
        BISProjectImport.BISProject proIbau = new BISProjectImport.BISProject();

        proIbau.project = new Map<String, Object>();

        proIbau.skippedAccountRoles = new Set<String>();

        // check if planStageCode is valid
        String planStageCode = xnProject.getAttribute('planstage_code', null);
        if (getProjectConstructionProgressValues.contains(planStageCode)) {
            proIbau.project.put('Project_Construction_Progress__c', planStageCode);
        }
        else {
            // 8: "auf Eis/unbekannt"
            // 9: "gestorben"
            if (planStageCode == '8' || planStageCode == '9') {
                // do not import projects with code 8 or 9 and delete them if already imported before
                proIbau.doDelete = true;
            }
            else {
                // add invalid value to enforce error
                proIbau.project.put('Project_Construction_Progress__c', planStageCode);
            }
        }

        proIbau.project.put('Name', xnProject.getAttribute('title', null));
        
        // parse relevant data from child elements
        String descr = '';
        List<Dom.XmlNode> xnCompanyroles = new List<Dom.XmlNode>();
        List<Dom.XmlNode> xnProjectChildList = xnProject.getChildElements();
        for (Dom.XmlNode xnProjectChild : xnProjectChildList) {
            if (xnProjectChild.getName() == 'projecttext') {
                String descContent = xnProjectChild.getAttribute('content', null);
                // skip blank values
                if (String.isNotBlank(descContent)) {
                    if (String.isNotBlank(descr)) {
                        // add separator between contents
                        descr += descSeparator;
                    }
                    descr += descContent;
                }
            } else if (xnProjectChild.getName() == 'companyrole') {
                xnCompanyroles.add(xnProjectChild);
            }
        }

        proIbau.project.put('Description__c', descr);
        proIbau.project.put('Project_ID_BIS__c', xnProject.getAttribute('externid', null));
        proIbau.project.put('External_ID__c', 'ibau_' + xnProject.getAttribute('externid', null));
        proIbau.project.put('iBau_ID__c', xnProject.getAttribute('id', null));
        //proIbau.project.put('Announcement_ID__c', '');
        String totalVol = xnProject.getAttribute('value', null);
        if (String.isNotBlank(totalVol)) {
            proIbau.project.put('Total_Volume__c', Decimal.valueOf(totalVol));
        }
        proIbau.project.put('Project_Construction_Start__c', xnProject.getAttribute('startdate', null));
        proIbau.project.put('Project_Construction_End__c', xnProject.getAttribute('enddate', null));
        //proIbau.project.put('Submission_Date__c', '');
        String addressStreet = xnProject.getAttribute('street', null);
        proIbau.project.put('Project_Address__Street__s', addressStreet);
        if(addressStreet != null && addressStreet != '') {
            DUPDuplicateCheckHelper.FormattedAddress formattedAddress = DUPDuplicateCheckHelper.formatAddress(addressStreet);
            proIbau.project.put('Street_cleaned__c', formattedAddress.street); 
            proIbau.project.put('House_Number_cleaned__c', formattedAddress.streetNumber);
        }
        proIbau.project.put('Project_Address__PostalCode__s', xnProject.getAttribute('postcode', null));
        proIbau.project.put('Project_Address__City__s', xnProject.getAttribute('town', null));
        proIbau.project.put('Project_Address__StateCode__s', xnProject.getAttribute('province_code', null));
        proIbau.project.put('Project_Address__CountryCode__s', xnProject.getAttribute('country_code', null));
        String latitude = xnProject.getAttribute('latitude', null);
        if (String.isNotBlank(latitude)) {
            proIbau.project.put('Project_Address__Latitude__s', Decimal.valueOf(latitude));
        }
        String longitude = xnProject.getAttribute('longitude', null);
        if (String.isNotBlank(longitude)) {
            proIbau.project.put('Project_Address__Longitude__s', Decimal.valueOf(longitude));
        }
        proIbau.project.put('Exact_Source__c', 'iBau');
        //proIbau.project.put('Project_URL__c', '');


        //parse companyroles as involved accounts
        proIbau.involvedAccounts = new List<InvolvedAccount>();

        for (Dom.XmlNode xnCR : xnCompanyroles) {
            InvolvedAccount involvedAcc = new InvolvedAccount();
            Dom.XmlNode xnCompany = xnCR.getChildElement('company', null);

            //create involved account
            involvedAcc.projectExternalId = (String) proIbau.project.get('External_ID__c');
            involvedAcc.accountId = xnCompany.getAttribute('externid', null);
            //account role handling 
            String accRole = xnCR.getAttribute('roletype_name', null);
            if (getAccountRoleMappingRecordsByBISValue.keySet().contains(accRole)) {
                involvedAcc.accountRole = getAccountRoleMappingRecordsByBISValue.get(accRole).SF_Picklist_Value__c;
            }
            else{
                proIbau.skippedAccountRoles.add(accRole);
                involvedAcc.accountRole = '';
            }

            involvedAcc.exactSource = 'ibau';
            involvedAcc.name = xnCompany.getAttribute('name1', null);
            involvedAcc.street = xnCompany.getAttribute('street', null);
            involvedAcc.postcode = xnCompany.getAttribute('postcode', null);
            involvedAcc.town = xnCompany.getAttribute('town', null);
            involvedAcc.countrycode = xnCompany.getAttribute('country_code', null);
            involvedAcc.email = xnCompany.getAttribute('email', null);
            involvedAcc.fax = xnCompany.getAttribute('fax', null);
            involvedAcc.phone = xnCompany.getAttribute('phone', null);
            involvedAcc.website = xnCompany.getAttribute('website', null);

            proIbau.involvedAccounts.add(involvedAcc);
        }
        return proIbau;
    }


    /**
     * Parses the JSON response string and returns all relevant 
     * project data for further processing.
     * 
     * @param   context     current import context (e.g. infobau or ibau)
     * @param   projectJSON  the project JSON string containing project data
     * 
     * @return  list of BISProjectImport.BISProject containing all relevant project data from JSON
     */
    public static ParseResult parseAndConvertProjectJSON(String context, String projectJSON) {
        System.debug('########## RP parseAndConvertProjectJSON: ' + context);
        ProjectList projectList = (ProjectList) JSON.deserialize(projectJSON, ProjectList.class);
        ParseResult pr = new ParseResult();

        // get total amount of project items to be imported
        pr.total = projectList.total;

        List<ProjectClass> xnItemList = projectList.items;
        System.debug('########## RP Items Size: ' + xnItemList.size());
        pr.projectItemsCount = xnItemList.size();
        Map<String,InvolvedAccount> involvedAccountsByAccountExternalId = new Map<String,InvolvedAccount>();

        // parse projects
        for (ProjectClass xnItem : xnItemList) {
            try {
                BISProjectImport.BISProject projectData;
                if (context == BISProjectImport.CONTEXT_IBAU_DE) {
                    //uncomment in future for JSON response from IBAU
                    //projectData = parseIbauProject(xnItem);
                }
                else if (context == BISProjectImport.CONTEXT_INFOBAU) {
                    projectData = parseInfobauProject(xnItem);
                }
                if (projectData != null) {
                    if (!projectData.doDelete) {
                        pr.projects.add(projectData);
                        pr.projectExternalIds.add((String) projectData.project.get('External_ID__c'));
                        for(InvolvedAccount invAcc : projectData.involvedAccounts){
                            involvedAccountsByAccountExternalId.put(invAcc.accountId, invAcc);
                        }
                        pr.involvedAccountsbyAccountExternalId = involvedAccountsByAccountExternalId;
                    }
                    else {
                        pr.projectExtIdToDelete.add((String) projectData.project.get('External_ID__c'));
                    }
                }
            }
            catch (Exception e) {
                System.debug('########## RP Exception: ' + e.getMessage());
                Core_Error_Log__c errorLog = UTLErrorLog.createErrorLogRecord(CLASSNAME, e, 'Error while parsing project XML: ' + e.getMessage(), null, BISProjectImport.SOURCESYSTEM, true);
                pr.errorLogs.put(errorLog.Core_Checksum__c, errorLog);
            }
        }
        return pr;
    }

    public static BISProjectImport.BISProject parseInfobauProject(ProjectClass xnProject) {
        BISProjectImport.BISProject proInfobau = new BISProjectImport.BISProject();
        List<InvolvedAccount> involvedAccs = new List<InvolvedAccount>();

        proInfobau.project = new Map<String, Object>();

        //determine project status
        if(xnProject.awardNotifications.size() > 0){
            proInfobau.project.put('Project_Construction_Progress__c', 'Vergabemeldung');
        }
        else if(xnProject.submissionResultHeaders.size() > 0){
            proInfobau.project.put('Project_Construction_Progress__c', 'Submissionsergebnis');
        }
        else if(xnProject.publicNotices.size() > 0){
            proInfobau.project.put('Project_Construction_Progress__c', 'Ausschreibung');
        }
        else{
            proInfobau.project.put('Project_Construction_Progress__c', 'InfoPlan');
        }

        proInfobau.project.put('Name', xnProject.title);

        if(xnProject.publicNotices.size() > 0){
            proInfobau.project.put('Description__c', xnProject.publicNotices[0].text.content);
        }
        proInfobau.project.put('Project_ID_BIS__c', xnProject.objectID);
        proInfobau.project.put('External_ID__c', 'infobau_' + xnProject.objectID);
        if(xnProject.awardNotifications.size() > 0){
            proInfobau.project.put('Announcement_ID__c', xnProject.awardNotifications[0].officialNumber);
        }
        proInfobau.project.put('BIS_Id__c', xnProject.id);
        proInfobau.project.put('Project_Construction_Start__c', xnProject.startDate);
        proInfobau.project.put('Project_Construction_End__c', xnProject.endDate);
        proInfobau.project.put('Submission_Date__c', xnProject.submissionDate);
        proInfobau.project.put('Project_Address__PostalCode__s', xnProject.mainSitePostcode);
        proInfobau.project.put('Project_Address__City__s', xnProject.mainSiteTown);
        proInfobau.project.put('Project_Address__StateCode__s', xnProject.parishPostcode.parish.district.province.officialCode);
        proInfobau.project.put('Project_Address__CountryCode__s', xnProject.mainSiteCountry);
        proInfobau.project.put('Exact_Source__c', 'infoBau');

        // submission results
        proInfobau.submissionResults = new List<Map<String, Object>>();
        Map<String, Map<String, Object>> submissionResultsByCompanyId = new Map<String, Map<String, Object>>();
        String submissionWinnerId = '';

        
        //involved accounts 
        proInfobau.involvedAccounts = new List<InvolvedAccount>();
        Map<String, InvolvedAccount> involvedAccountsbyCompanyId = new Map<String, InvolvedAccount>();

        //add winner in awardNotifications as first submission result
        if(xnProject.awardNotifications.size() > 0){
            Map<String, Object> sr = new Map<String, Object>();
            InvolvedAccount involvedAcc = new InvolvedAccount();
            
            if(xnProject.awardNotifications[0].awardNotificationCompanies.size() > 0){
                AwardNotificationCompanyClass xnCompany = xnProject.awardNotifications[0].awardNotificationCompanies[0].company;
                String companyId = xnCompany.externalID;
                String projectExtId = (String) proInfobau.project.get('External_ID__c');
                submissionWinnerId = xnCompany.id;

                //create submission result
                sr.put('Company__c', xnCompany.name1);
                sr.put('Project__c', projectExtId);
                sr.put('Quote_Amount__c', xnProject.constructionSum);
                sr.put('Winner__c', true);
                sr.put('External_ID__c', projectExtId + '_' + companyId);

                //create involved account
                involvedAcc.projectExternalId = projectExtId;
                involvedAcc.accountId = companyId;
                
                if(getAccountRoleMappingRecordsByBISValue.keySet().contains('Gewinner')){
                    involvedAcc.accountRole = getAccountRoleMappingRecordsByBISValue.get('Gewinner').SF_Picklist_Value__c;
                }
                else{
                    involvedAcc.accountRole = '';
                }

                involvedAcc.exactSource = 'infobau';
                involvedAcc.name = xnCompany.name1;
                involvedAcc.street = xnCompany.street + ' ' + xnCompany.houseNo;
                involvedAcc.postcode = xnCompany.postcode;
                involvedAcc.town = xnCompany.town;
                involvedAcc.countrycode = xnCompany.country;

                if(xnCompany.contactSpecifications != null && !xnCompany.contactSpecifications.isEmpty()){
                    for(ContactSpecification conSpec : xnCompany.contactSpecifications){
                        if(conSpec.contactSpecificationType.code == 'PHONE'){
                            involvedAcc.phone = conSpec.content;
                        }
                        else if(conSpec.contactSpecificationType.code == 'MAIL'){
                            involvedAcc.email = conSpec.content;
                        }
                        else if(conSpec.contactSpecificationType.code == 'FAX'){
                            involvedAcc.fax = conSpec.content;
                        }
                        else if(conSpec.contactSpecificationType.code == 'URL'){
                            involvedAcc.website = conSpec.content;
                        }
                    }
                }

                if(String.isNotBlank(companyId)){
                    //submissionResultsByCompanyId.put(companyId, sr);
                    if (!submissionResultsByCompanyId.containsKey(companyId) || ((Boolean) submissionResultsByCompanyId.get(companyId).get('Winner__c')) == false) {
                        submissionResultsByCompanyId.put(companyId, sr);
                    }
                    involvedAccountsbyCompanyId.put(companyId, involvedAcc);
                }
                else {
                    String errorMessage = 'Missing value in company.externid for Company \'' + sr.get('Company__c') + '\' of Project \'' + projectExtId + '\'';
                    throw new BISProjectImport.BISImportException(errorMessage);
                }
            }
        }

        //add rest of submission results
        if(xnProject.submissionResultHeaders.size() > 0){
            for (SubmissionResult xnCR : xnProject.submissionResultHeaders[0].submissionResults) {
                Map<String, Object> sr = new Map<String, Object>();
                InvolvedAccount involvedAcc = new InvolvedAccount();
                SubmissionCompany xnCompany = xnCR.company;

                //ensure that winner is not added twice to submission results
                if(xnCompany.id != submissionWinnerId){
                    String companyId = xnCompany.externalID;
                    String projectExtId = (String) proInfobau.project.get('External_ID__c');

                    //create submission result
                    sr.put('Company__c', xnCompany.name1);
                    sr.put('Project__c', projectExtId);
                    sr.put('Quote_Amount__c', xnCR.value);
                    sr.put('External_ID__c', projectExtId + '_' + companyId);

                    //create involved account
                    involvedAcc.projectExternalId = projectExtId;
                    involvedAcc.accountId = companyId;

                    if(getAccountRoleMappingRecordsByBISValue.keySet().contains('Bieter')){
                        involvedAcc.accountRole = getAccountRoleMappingRecordsByBISValue.get('Bieter').SF_Picklist_Value__c;
                    }
                    else{
                        involvedAcc.accountRole = '';
                    }

                    involvedAcc.exactSource = 'infobau';
                    involvedAcc.name = xnCompany.name1;
                    involvedAcc.street = xnCompany.street + ' ' + xnCompany.houseNo;
                    involvedAcc.postcode = xnCompany.postcode;
                    involvedAcc.town = xnCompany.town;
                    involvedAcc.countrycode = xnCompany.country;

                    if(xnCompany.contactSpecifications != null && !xnCompany.contactSpecifications.isEmpty()){
                        for(ContactSpecification conSpec : xnCompany.contactSpecifications){
                            if(conSpec.contactSpecificationType.code == 'PHONE'){
                                involvedAcc.phone = conSpec.content;
                            }
                            else if(conSpec.contactSpecificationType.code == 'MAIL'){
                                involvedAcc.email = conSpec.content;
                            }
                            else if(conSpec.contactSpecificationType.code == 'FAX'){
                                involvedAcc.fax = conSpec.content;
                            }
                            else if(conSpec.contactSpecificationType.code == 'URL'){
                                involvedAcc.website = conSpec.content;
                            }
                        }
                    }


                    if (String.isNotBlank(companyId)) {
                        // ensure that winner is not overwritten by bieter entry <--- check here
                        if (!submissionResultsByCompanyId.containsKey(companyId) || ((Boolean) submissionResultsByCompanyId.get(companyId).get('Winner__c')) == false) {
                            submissionResultsByCompanyId.put(companyId, sr);
                            involvedAccountsbyCompanyId.put(companyId, involvedAcc);
                        }
                    }
                    else {
                        String errorMessage = 'Missing value in company.externid for Company \'' + sr.get('Company__c') + '\' of Project \'' + projectExtId + '\'';
                        throw new BISProjectImport.BISImportException(errorMessage);
                    }
                }
            }
        }
        
        proInfobau.submissionResults = submissionResultsByCompanyId.values();
        proInfobau.involvedAccounts = involvedAccountsbyCompanyId.values();

        return proInfobau;
    }

    /**
     * Wrapper class for parsing results
     */
    public class ParseResult {
        public Integer total;
        public Integer projectItemsCount;
        public List<BISProjectImport.BISProject> projects;
        public Set<String> projectExternalIds;
        public Map<String,InvolvedAccount> involvedAccountsbyAccountExternalId;
        public Map<String,Core_Error_Log__c> errorLogs;
        public Set<String> projectExtIdToDelete;

        /** Constructor **/
        public ParseResult() {
            this.total = 0;
            this.projectItemsCount = 0;
            this.projects = new List<BISProjectImport.BISProject>();
            this.errorLogs = new Map<String,Core_Error_Log__c>();
            this.projectExtIdToDelete = new Set<String>();
            this.projectExternalIds = new Set<String>();
            this.involvedAccountsbyAccountExternalId = new Map<String,InvolvedAccount>();
        }
    }

    /**
     * Wrapper class for either Project_Account_Relation__c or 	Project_Account_Lead_Relation__c
     */
    public class InvolvedAccount{
        public String projectExternalId; 
        public String accountId; 
        public String accountRole;
        public String exactSource;  
        //public Date startDate; 
        //public Date endDate;
        public String name;
        public String street;
        public String postcode; 
        public String town;
        public String countrycode; 
        public String email;
        public String fax; 
        public String phone;
        public String website;
    }

    /**
     * Wrapper class for JSON Project Response
     */

    public class ProjectList {
        public Integer total; 
        public List<ProjectClass> items;
    }

    public class ProjectClass{
        public String id; 
        public String title; 
        public String startDate; 
        public String endDate; 
        public String submissionDate; 
        public String mainSitePostcode; 
        public String mainSiteTown; 
        public String mainSiteCountry;
        public String objectID;
        public Boolean isWinner;
        public Integer constructionSum;

        public ParishPostcodeClass parishPostcode;
        public List<PublicNotice> publicNotices;
        public List<AwardNotification> awardNotifications;
        public List<PublicNoticeCompany> publicNoticeCompanies;
        public List<SubmissionResultHeader> submissionResultHeaders;
    }

    public class ParishPostcodeClass{
        public ParishClass parish;
    }

    public class ParishClass{
        public DistrictClass district;
    }

    public class DistrictClass{
        public ProvinceClass province;
    }

    public class ProvinceClass{
        public String officialCode;
    }


    public class PublicNotice{
        public String performanceSpecification;
        public TextClass text; 
    }

    public class TextClass{
        public String content; 
    }

    public class AwardNotification{
        public String officialNumber;
        public Integer awardValue;
        public List<AwardNotificationCompany> awardNotificationCompanies;
    }

    public class AwardNotificationCompany{
        public awardNotificationCompanyClass company;
    }

    public class AwardNotificationCompanyClass{
        public String id;
        public String name1;
        public String street; 
        public String houseNo;
        public String postcode;
        public String town; 
        public String country; 
        public String externalID; 
        public List<ContactSpecification> contactSpecifications; 
    }

    public class ContactSpecification{
        public String id;
        public String content;
        public contactSpecificationTypes contactSpecificationType; 
    }

    public class contactSpecificationTypes{
        public String code;
        public String name;
    }

    public class PublicNoticeCompany{
        public CompanyClass company;
    }

    public class CompanyClass{
        public ParishPostcodeCompanyClass parishPostcode;
        public String name1;
        public String externalID;
    }

    public class ParishPostcodeCompanyClass{
        public ParishCompanyClass parish;
    }

    public class ParishCompanyClass{
        public DistrictCompanyClass district;
        public String name;
    }

    public class DistrictCompanyClass{
        public ProvinceCompanyClass province;
    }

    public class ProvinceCompanyClass{
        public String officialCode;
    }

    public class SubmissionResultHeader{
        public List<SubmissionResult> submissionResults;
    }

    public class SubmissionResult{
        public Integer value;
        public Integer ranking;
        public SubmissionCompany company; 
    }

    public class SubmissionCompany{
        public String id;
        public String name1;
        public String street;
        public String houseNo;
        public String postcode;
        public String town; 
        public String country; 
        public String externalID; 
        public List<ContactSpecification> contactSpecifications; 

    }

}