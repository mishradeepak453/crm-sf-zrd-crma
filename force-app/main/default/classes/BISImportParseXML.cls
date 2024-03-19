/**
 * SF-647: Helper class to parse Project XML  
 * and convert it for further processing.
 * 
 * @author  rene.pienkoss@accenture.com
 * 
 * @version 2021-12-02  rene.pienkoss@accenture.com     creation
 * @version 2022-05-05  rene.pienkoss@accenture.com     added property to count items received in JSON
 */
public class BISImportParseXML {
    
    public static final String CLASSNAME = 'BISImportParseXML';

    // separator to be used between different description values
    private static final String descSeparator = '<br>----------<br>';

    private static Set<String> projectConstructionProgressValues;

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
        //System.debug('########## RP Total Items: ' + pr.total);

        Dom.XmlNode xnItems = xnResult.getChildElement('items', null);
        List<Dom.XmlNode> xnItemList = xnItems.getChildElements();
        //System.debug('########## RP Items Size: ' + xnItemList.size());
        pr.projectItemsCount = xnItemList.size();

        // parse projects
        for (Dom.XmlNode xnItem : xnItemList) {
            Dom.XmlNode xnProject = xnItem.getChildElement('project', null);
            
            try {
                BISProjectImport.BISProject projectData;
                if (context == BISProjectImport.CONTEXT_IBAU_DE) {
                    projectData = parseIbauProject(xnProject);
                }/*
                else if (this.context == CONTEXT_IBAU_AT) {

                }*/
                else if (context == BISProjectImport.CONTEXT_INFOBAU) {
                    projectData = parseInfobauProject(xnProject);
                }

                if (projectData != null) {
                    if ( ! projectData.doDelete) {
                        pr.projects.add(projectData);
                    }
                    else {
                        pr.projectExtIdToDelete.add((String) projectData.project.get('External_ID__c'));
                    }
                }/*
                else {
                    System.debug('########## RP projectData is null: ' + xnProject);
                }*/
            }
            catch (Exception e) {
                System.debug('########## RP Exception: ' + e.getMessage());
                pr.errorLogs.add(UTLErrorLog.createErrorLogRecord(CLASSNAME, e, 'Error while parsing project XML: ' + e.getMessage(), null, BISProjectImport.SOURCESYSTEM, true));
            }
        }

        return pr;
    }

    /**
     * Parse XML of ibau projects
     */
    public static BISProjectImport.BISProject parseIbauProject(Dom.XmlNode xnProject) {
        BISProjectImport.BISProject proIbau = new BISProjectImport.BISProject();

        proIbau.project = new Map<String, Object>();

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
                //System.debug('########## RP planstage_code value not supported -> skip project: ' + planStageCode);
                //return null;

                // add invalid value to enforce error
                proIbau.project.put('Project_Construction_Progress__c', planStageCode);
            }
        }

        proIbau.project.put('Name', xnProject.getAttribute('title', null));
        
        // parse relevant data from child elements
        String descr = '';
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
        proIbau.project.put('Project_Address__Street__s', xnProject.getAttribute('street', null));
        proIbau.project.put('Project_Address__PostalCode__s', xnProject.getAttribute('postcode', null));
        proIbau.project.put('Project_Address__City__s', xnProject.getAttribute('town', null));
        proIbau.project.put('Project_Address__StateCode__s', xnProject.getAttribute('province_code', null));
        proIbau.project.put('Project_Address__CountryCode__s', xnProject.getAttribute('country_code', null));
        proIbau.project.put('Exact_Source__c', 'iBau');
        //proIbau.project.put('Project_URL__c', '');

        return proIbau;
    }

    /**
     * Parse XML of infobau projects
     */
    public static BISProjectImport.BISProject parseInfobauProject(Dom.XmlNode xnProject) {
        BISProjectImport.BISProject proInfobau = new BISProjectImport.BISProject();

        proInfobau.project = new Map<String, Object>();

        String sourceValue = xnProject.getAttribute('source', null);
        if (String.isNotBlank(sourceValue)) {
            proInfobau.project.put('Project_Construction_Progress__c', xnProject.getAttribute('source', null));
        }
        else {
            System.debug('########## RP source value is blank -> skip project: ' + sourceValue);
            return null;
        }
        proInfobau.project.put('Name', xnProject.getAttribute('title', null));

        // parse relevant data from child elements
        String descr = '';
        List<Dom.XmlNode> xnCompanyroles = new List<Dom.XmlNode>();
        for (Dom.XmlNode xnProjectChild : xnProject.getChildElements()) {
            if (xnProjectChild.getName() == 'projecttender') {
                List<Dom.XmlNode> xnChildsLevel2 = xnProjectChild.getChildElements();
                for (Dom.XmlNode xnChildLevel2 : xnChildsLevel2) {
                    if (xnChildLevel2.getName() == 'tendertext') {
                        String descContent = xnChildLevel2.getAttribute('content', null);
                        // skip blank values
                        if (String.isNotBlank(descContent)) {
                            if (String.isNotBlank(descr)) {
                                // add separator between contents
                                descr += descSeparator;
                            }
                            descr += descContent;
                        }
                    }
                }
            }
            else if (xnProjectChild.getName() == 'companyrole') {
                xnCompanyroles.add(xnProjectChild);
            }
        }

        proInfobau.project.put('Description__c', descr);
        proInfobau.project.put('Project_ID_BIS__c', xnProject.getAttribute('externid', null));
        proInfobau.project.put('External_ID__c', 'infobau_' + xnProject.getAttribute('externid', null));
        proInfobau.project.put('Announcement_ID__c', xnProject.getAttribute('vergabe_nr', null));
        //proInfobau.project.put('Total_Volume__c', '');
        proInfobau.project.put('Project_Construction_Start__c', xnProject.getAttribute('startdate', null));
        proInfobau.project.put('Project_Construction_End__c', xnProject.getAttribute('bauende', null));
        proInfobau.project.put('Submission_Date__c', xnProject.getAttribute('submissionsdatum', null));
        //proInfobau.project.put('Project_Address__Street__s', xnProject.getAttribute('street', null));
        proInfobau.project.put('Project_Address__PostalCode__s', xnProject.getAttribute('postcode', null));
        proInfobau.project.put('Project_Address__City__s', xnProject.getAttribute('town', null));
        proInfobau.project.put('Project_Address__StateCode__s', xnProject.getAttribute('province_code', null));
        proInfobau.project.put('Project_Address__CountryCode__s', xnProject.getAttribute('country_code', null));
        proInfobau.project.put('Exact_Source__c', 'infoBau');
        //proInfobau.project.put('Project_URL__c', '');

        // submission results
        //System.debug('########## RP xnCompanyroles: ' + xnCompanyroles.size());
        proInfobau.submissionResults = new List<Map<String, Object>>();
        Map<String, Map<String, Object>> submissionResultsByCompanyId = new Map<String, Map<String, Object>>();
        Set<String> winnerCompanyIds = new Set<String>();
        for (Dom.XmlNode xnCR : xnCompanyroles) {
            String roleType = xnCR.getAttribute('roletype_name', null);
            if (roleType == 'bieter' || roleType == 'winner') {
                Map<String, Object> sr = new Map<String, Object>();
                Dom.XmlNode xnCompany = xnCR.getChildElement('company', null);
                String companyId = xnCompany.getAttribute('externid', null);
                String projectExtId = (String) proInfobau.project.get('External_ID__c');

                sr.put('Company__c', xnCompany.getAttribute('name1', null));
                sr.put('Project__c', projectExtId);
                String quoteAmount = xnCompany.getAttribute('angebotssumme', null);
                if (String.isNotBlank(quoteAmount)) {
                    sr.put('Quote_Amount__c', Decimal.valueOf(quoteAmount));
                }
                sr.put('Winner__c', roleType == 'winner');
                sr.put('External_ID__c', projectExtId + '_' + companyId);

                if (String.isNotBlank(companyId)) {
                    // ensure that winner is not overwritten by bieter entry
                    if ( ! submissionResultsByCompanyId.containsKey(companyId) || ((Boolean) submissionResultsByCompanyId.get(companyId).get('Winner__c')) == false) {
                        submissionResultsByCompanyId.put(companyId, sr);
                    }
                }
                else {
                    String errorMessage = 'Missing value in company.externid for Company \'' + sr.get('Company__c') + '\' of Project \'' + projectExtId + '\'';
                    throw new BISProjectImport.BISImportException(errorMessage);
                }
            }
            else if (roleType == 'Bauherr') {
                String announcer = '';

                Dom.XmlNode xnCompany = xnCR.getChildElement('company', null);
                String companyName = xnCompany.getAttribute('name1', null);
                String companyPostcode = xnCompany.getAttribute('postcode', null);
                String companyTown = xnCompany.getAttribute('town', null);

                if (String.isNotBlank(companyName)) {
                    announcer += companyName + ', ';
                }
                if (String.isNotBlank(companyPostcode)) {
                    announcer += companyPostcode + ' ';
                }
                if (String.isNotBlank(companyTown)) {
                    announcer += companyTown;
                }
                proInfobau.project.put('Announcer__c', announcer);
            }
        }

        proInfobau.submissionResults = submissionResultsByCompanyId.values();

        return proInfobau;
    }

    /**
     * Wrapper class for parsing results
     */
    public class ParseResult {
        public Integer total;
        public Integer projectItemsCount;
        public List<BISProjectImport.BISProject> projects;
        public List<Core_Error_Log__c> errorLogs;
        public Set<String> projectExtIdToDelete;

        /** Constructor **/
        public ParseResult() {
            this.total = 0;
            this.projectItemsCount = 0;
            this.projects = new List<BISProjectImport.BISProject>();
            this.errorLogs = new List<Core_Error_Log__c>();
            this.projectExtIdToDelete = new Set<String>();
        }
    }
}