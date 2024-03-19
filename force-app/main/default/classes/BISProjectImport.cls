/**
 * SF-647: Queueable job to import Project__c record from BIS (ESB).
 * 
 * @author  rene.pienkoss@accenture.com
 * 
 * @version 2021-10-22  rene.pienkoss@accenture.com       creation
 * @version 2022-05-05  rene.pienkoss@accenture.com       1) fixed issue where job runs in an infinite loop (check if items recevied for current page)
 *                                                        2) count items received instead of projects list size
 *                                                        3) always update timestamp if job is finished
 * @version 2022-07-19  miriam.ida.tyroller@accenture.com fixed issue where projects without a startdate were skipped
 * @version 2023-02-01  miriam.ida.tyroller@accenture.com adjusted logic to parse JSON response from infobau
 * @version 2023-04-14  rene.pienkoss@accenture.com       SF-1111: ibau: always update existing projects, even if they no longer meet the import criteria
 * @version 2023-09-01  miriam.ida.tyroller@accenture.com adjusted handle involved accounts
 * @version 2023-10-30 isabella.moos@accenture.com        added exception for running test for SF-1205
 */
public class BISProjectImport implements Queueable, Database.AllowsCallouts {

    public static final String CLASSNAME = 'BISProjectImport';
    public static final String SOURCESYSTEM = 'BIS';
    public static final String CONTEXT_IBAU_DE = 'ibau_de';
    public static final String CONTEXT_IBAU_AT = 'ibau_at';
    public static final String CONTEXT_INFOBAU = 'infobau';

    @TestVisible
    private static final Map<String, String> timestampFieldNamesByContext = new Map<String, String>{
        CONTEXT_IBAU_DE => 'Last_Import_Ibau_DE__c',
        CONTEXT_IBAU_AT => 'Last_Import_Ibau_AT__c',
        CONTEXT_INFOBAU => 'Last_Import_Infobau__c'
    };

    private static final Map<String, String> requestFilterByContext = new Map<String, String>{
        CONTEXT_IBAU_DE => 'Filter_JSON_Ibau_DE__c',
        CONTEXT_IBAU_AT => 'Filter_JSON_Ibau_AT__c',
        CONTEXT_INFOBAU => 'Filter_JSON_Infobau__c'
    };

    // current context values
    @TestVisible
    private ContextVars conVars;

    // the list of error logs that occurred during current run
    @TestVisible
    private Map<String,Core_Error_Log__c> errorLogs = new Map<String,Core_Error_Log__c>();

    @TestVisible
    private Boolean testError = false;
    @TestVisible
    private Boolean testRetry = false;


    /**
     * Constructor to start import
     */
    public BISProjectImport(String context) {
        if (context != CONTEXT_IBAU_DE && context != CONTEXT_IBAU_AT && context != CONTEXT_INFOBAU) {
            throw new BISImportException('Invalid arguments: Unsupported context \'' + context + '\'');
        }

        // init context vars
        this.conVars = new ContextVars(context);

        // set timestamp of last update request
        BIS_Project_Import_Config__c conf = BIS_Project_Import_Config__c.getOrgDefaults();
        Decimal lastImportTimestamp = (Decimal) conf.get(timestampFieldNamesByContext.get(this.conVars.context));

        System.debug(lastImportTimestamp);
        if (lastImportTimestamp != null) {
            this.conVars.lastUpdateTime = lastImportTimestamp.longValue();
        }

        // set request filter
        this.conVars.requestFilter = (String) conf.get(requestFilterByContext.get(this.conVars.context));
        
        // set page size (max. 250)
        this.conVars.pageSize = (conf.Page_Size__c != null && Integer.valueOf(conf.Page_Size__c) > 0) ? Integer.valueOf(conf.Page_Size__c) : 250;

        // set retry limit
        this.conVars.retryLimit = (conf.Retry_Limit__c != null && Integer.valueOf(conf.Retry_Limit__c) > -1) ? Integer.valueOf(conf.Retry_Limit__c) : 3;

        // set handler involved Accounts
        this.conVars.handleInvolvedAccounts = conf.Include_Involved_Accounts__c;

        //get placeholder for construction start date
        this.conVars.startDatePlaceholder = conf.Project_Construction_Start_Placeholder__c;
    }

    /**
     * Constructor for pagination
     */
    public BISProjectImport(ContextVars conVars) {
        this(conVars, false);
    }

    /**
     * Constructor for retry current page request
     */
    public BISProjectImport(ContextVars conVars, Boolean isRetry) {
        this.conVars = conVars;

        if (!isRetry) {
            // handle next page
            this.conVars.setNextPage();
        }
        else {
            // set next attempt for current page
            this.conVars.setNextAttempt();
        }
    }

    /**
     * Start import.
     */
    public void execute(QueueableContext qc) {
        System.debug('########## RP execute: ' + this.conVars.context);
        System.debug('########## RP Page: ' + this.conVars.currentPage);
        System.debug('########## RP Attempt: ' + this.conVars.requestAttempt);

        try {    
            // create an send request
            Http h = new Http();
            HttpRequest req = new HttpRequest();
            
            // Set Endpoint
            String ep;
            if (this.conVars.context == CONTEXT_IBAU_DE) {
                req.setMethod('GET');
                ep = 'callout:Projects_Ibau_DE';
            }
            else if (this.conVars.context == CONTEXT_IBAU_AT) {
                req.setMethod('GET');
                ep = 'callout:Projects_Ibau_AT';
            }
            else if (this.conVars.context == CONTEXT_INFOBAU) {
                req.setMethod('POST');
                //ep = 'callout:Projects_Infobau';
                ep = 'callout:Projects_Infobau_New';
            }

            // Parameters
            String epParams = '?page=' + this.conVars.currentPage;
            epParams += '&size=' + this.conVars.pageSize;
            
            if (this.conVars.lastUpdateTime != null) {
                if (this.conVars.context == CONTEXT_IBAU_DE || this.conVars.context == CONTEXT_IBAU_AT) {
                    // convert from milliseconds to seconds
                    epParams += '&created_at=' + (this.conVars.lastUpdateTime / 1000);
                }
                else if (this.conVars.context == CONTEXT_INFOBAU) {
                    //convert unix timestamp to date string for infobau filter
                    DateTime lastUpdateDatetime = DateTime.newInstance(this.conVars.lastUpdateTime);
                    Date lastUpdateDate = date.newinstance(lastUpdateDatetime.year(), lastUpdateDatetime.month(), lastUpdateDatetime.day());
                    lastUpdateDate = lastUpdateDate.addDays(-1);
                    String lastUpdateString = String.valueOf(lastUpdateDate);
                    req.setBody('{lastUpdate: {$gte: ISODate("' + lastUpdateString + '")}}');
                }  
            }
            
            if (String.isNotBlank(this.conVars.requestFilter)) {
                // add query filter
                epParams += '&json_query=' + urlEncodeSpacesAsPercentValue(this.conVars.requestFilter);
            }

            req.setEndpoint(ep + epParams);

            System.debug('########## RP Parameters: ' + ep + epParams);
            System.debug('########## RP Body: ' + req.getBody());

            req.setTimeout(60000);
            
            HttpResponse res;
            if (!Test.isRunningTest()) {
                res = h.send(req);
            }
            else {
                // create dummy response
                res = new HttpResponse();

                if (!testRetry) {
                    res.setStatusCode(200);
                }
                else {
                    res.setStatusCode(500);
                }

                if (this.conVars.context == CONTEXT_IBAU_DE) {
                    // ibau XML
                    res.setBody('<?xml version="1.0" encoding="UTF-8"?><result total="1" page="1" size="'+this.conVars.pageSize+'"><items><item id="287083" created_at="1642491606.965852" updated_at="1642491606.965852"><project source="Alert: Übergabe Schnittstelle" allocationdate="2019-10-29 12:19:41" id="1020106" externid="1714447" '+
                                'title="&quot;Leeschenhof&quot; - Neubau einer Wohn- und Geschäftshausanlage mit Tiefgarage" postcode="79361" town="Düsseldorf" street="Oberbilker Allee 51-56" value="28000000" valuedescr="12.000 qm BGF" startdate="2022-03-01 00:00:00" enddate="2049-12-01 00:00:00" '+
                                'basearea="0" sitearea="0" floorarea="12000" roofarea="0" storeys="0" structures="0" volume="0" parkingspaces="200" apartments="71" researcher="a.krebs@ibau.de" created="2014-03-19 11:52:18" modified="2019-10-29 11:14:02" imported="2019-10-29 11:28:01" '+
                                'latitude="51.2109681" longitude="6.7888462" latitude_open="51.2110935" longitude_open="6.7856144" geo_confidence_open="9" country_name="Deutschland" country_code="D" province_name="Nordrhein-Westfalen" province_code="05" district_name="Düsseldorf, Stadt" district_code="05111" '+
                                'parish_name="Düsseldorf, Stadt" parish_code="05111000" planstage_name="Planung" planstage_code="5" oldplanstage_name="Planung" oldplanstage_code="3" rooftype_name="Flachdach und geneigtes Dach" rooftype_code="DD" projecttype_name="gewerblicher Hochbau" projecttype_code="999C">'+
                                '<projecttext content="beschränkt an Generalunternehmer/Generalübernehmer" projecttexttype_id="6" texttype_name="Ausschreibungsart" texttype_code="50"/>'+
                                '<companyrole id="742088" ismaincontact="0" companyroletype_id="1" created="2008-07-02 00:00:00" roletype_name="Bauherr" roletype_code="100">'+
                                    '<company id="10195" externid="' + BISProjectImportTest.IBAU_ID_TESTING + '" name1="Stadt Fröndenberg/Ruhr" street="Bahnhofstr. 2" postcode="58730" town="Test City" phone="02373/456" fax="02373/999" email="stadt@test.de" website="http://www.test.de" language_id="1" project_count="9" country_name="Deutschland" country_code="D" province_name="Nordrhein-Westfalen" province_code="05" district_name="Unna" district_code="05978" parish_name="Fröndenberg/Ruhr, Stadt" parish_code="05978012" />'+
                                '</companyrole>'+
                                '<companyrole id="742091" ismaincontact="0" companyroletype_id="18" created="2008-07-02 00:00:00" roletype_name="Zuständige Behörde" roletype_code="140">'+
                                    '<company id="5434" externid="1309320" name1="Stadtverwaltung Fröndenberg" street="Bahnhofstr. 2" postcode="58730" town="Test City" phone="02373/12345" fax="02373/12345" email="test@test.de" website="http://www.test.de" language_id="1" project_count="10" country_name="Deutschland" country_code="D" province_name="Nordrhein-Westfalen" province_code="05" district_name="Unna" district_code="05978" parish_name="Fröndenberg/Ruhr, Stadt" parish_code="05978012" />'+
                                '</companyrole>'+
                                '<companyrole id="742092" ismaincontact="0" companyroletype_id="18" created="2008-07-02 00:00:00" roletype_name="Zuständige Behörde" roletype_code="140">'+
                                    '<company id="5435" externid="' + BISProjectImportTest.IBAU_DOUBLE_ID_TESTING + '" name1="ACN Test Account BIS Import 2" street="Test Street 9" postcode="12345" town="City" phone="+49987654" fax="123456" email="testacc@test.com" website="http://www.test.de" language_id="1" project_count="11" country_name="Deutschland" country_code="D" province_name="Nordrhein-Westfalen" province_code="05" district_name="Unna" district_code="05978" parish_name="Fröndenberg/Ruhr, Stadt" parish_code="05978012" />'+
                                '</companyrole>'+
                                '<companyrole id="742093" ismaincontact="0" companyroletype_id="18" created="2008-07-02 00:00:00" roletype_name="Zuständige Behörde" roletype_code="140">'+
                                    '<company id="5436" externid="' + BISProjectImportTest.IBAU_DOUBLE_ID_TESTING + '" name1="ACN Test Account BIS Import 2" street="Test Street 3" postcode="54321" town="Town" phone="+49567896" fax="765432" email="testacc@mail.com" website="http://www.bis.de" language_id="1" project_count="12" country_name="Deutschland" country_code="D" province_name="Nordrhein-Westfalen" province_code="05" district_name="Unna" district_code="05978" parish_name="Fröndenberg/Ruhr, Stadt" parish_code="05978012" />'+
                                '</companyrole>'+
                                '</project></item></items></result>');
                }
                else if (this.conVars.context == CONTEXT_INFOBAU) {
                    // infobau JSON
                    res.setBody('{"items":[{"id":780677,"objectID":"12345","title":"ITLeerrohreNRH-EUB","constructionSum":232975,"mainSitePostcode":"92637","mainSiteTown":"Weiden","mainSiteCountry":"GER","parishPostcode":{"parish":{"district":{"province":{"officialCode":"BY"}}}},"submissionDate":"2020-06-27T22:00:00+00:00","startDate":"1970-01-01T23:00:00.000Z",'+
                    '"endDate":"1970-01-01T23:00:00.000Z","publicNotices":[{"text": {"content": "test Description"},"performanceSpecification":"test Description"}],'+
                    '"submissionResultHeaders":[{"submissionResults":['+
                        '{"company":{"id":1286,"name1":"SchiederBauGmbH","town":"Bechtsrieth","postcode":"92699","country":"GER","externalID":"6000210"},"value":232975,"ranking":1},'+
                        '{"company":{"id":9393,"name1":"HieroldBauGmbH","town":"Moosbach","postcode":"92709","country":"GER","externalID":"' + BISProjectImportTest.INFOBAU_ID_TESTING + '"},"value":237788,"ranking":2},'+
                        '{"company":{"id":1292,"name1":"hermannpaulGmbH","town":"Weiden","postcode":"92637","country":"GER","externalID":"4040503"},"value":310049,"ranking":3},'+
                        '{"company":{"id":345,"name1":"ACN Test Account BIS Import 2","town":"City","postcode":"12345","country":"GER","externalID":"'+ BISProjectImportTest.INFOBAU_DOUBLE_ID_TESTING +'"},"value":150,"ranking":4},'+
                        '{"company":{"id":876,"name1":"ACN Test Account BIS Import 3","town":"Town","postcode":"54321","country":"GER","externalID":"'+ BISProjectImportTest.INFOBAU_DOUBLE_ID_TESTING +'"},"value":300,"ranking":5}'+
                        ']}],'+
                    '"publicNoticeCompanies":['+
                        '{"company":{"id":2029,"name1":"StadtWeiden","parishPostcode":{"parish":{"name":"Weiden","district":{"province":{"officialCode":"BY"}}}},"externalID":"3312516"}}],'+
                    '"awardNotifications":[{"awardValue":12345,"officialNumber":"","awardNotificationCompanies":[' +
                        '{"company":{"id":1286,"name1":"SchiederBauGmbH","town":"Bechtsrieth","postcode":"92699","country":"GER","externalID":"6000210"}'+
                    '}]}],"externalID":"1899908"}],"page":1,"size":"'+this.conVars.pageSize+'","total":1}');
                }
            }
            System.debug('########## RP BIS Project Response Status: ' + res.getStatusCode());
            
            if (res.getStatusCode() == 200) {
                BISImportParse.ParseResult pr = new BISImportParse.ParseResult();
                
                // parse response XML for ibau and response JSON for infobau
                if (this.conVars.context == CONTEXT_IBAU_DE) {
                    pr = BISImportParse.parseAndConvertProjectXML(this.conVars.context, res.getBody());
                }
                else if (this.conVars.context == CONTEXT_INFOBAU){
                    pr = BISImportParse.parseAndConvertProjectJSON(this.conVars.context, res.getBody());
                }

                // collect errors
                if (!pr.errorLogs.isEmpty()) {
                    this.errorLogs.putAll(pr.errorLogs);
                }
                Integer receivedCount = pr.projectItemsCount;
                // increase number of received projects
                this.conVars.projectsReceived += receivedCount;

                System.debug('########## RP Current Page Received Items: ' + receivedCount + ' (Import: ' + pr.projects.size() + ', Delete: ' + pr.projectExtIdToDelete.size() + ')');
                System.debug('########## RP Total Received Items: ' + this.conVars.projectsReceived);
                System.debug('########## RP Total Items: ' + pr.total);

                if (!pr.projects.isEmpty()) {
                    ProjectData pd = new ProjectData();
                    Map<String, List<Account>> existingAccountsbyExternalId = new Map<String, List<Account>>();
                    Map<String, Account_Lead__c> existingAccountLeadsbyExternalId = new Map<String, Account_Lead__c>();
                    Map<String, Account_Lead__c> updatedExistingAccountLeadsbyExternalId = new Map<String, Account_Lead__c>();
                    Map<String, Project__c> existingProjectsByExternalId = new Map<String, Project__c>();

                    if (this.conVars.context == CONTEXT_IBAU_DE) {
                        for (Account acc : [SELECT Id, Ibau_Id__c, Infobau_Id__c FROM Account WHERE Ibau_Id__c IN :pr.involvedAccountsbyAccountExternalId.keySet()]) {
                            if(existingAccountsbyExternalId.keySet().contains(acc.Ibau_Id__c)){
                                List<Account> accountList = existingAccountsbyExternalId.get(acc.Ibau_Id__c);
                                accountList.add(acc);
                                existingAccountsbyExternalId.put(acc.Ibau_Id__c, accountList);
                            } else {
                                List<Account> accountList = new List<Account>{acc};
                                existingAccountsbyExternalId.put(acc.Ibau_Id__c, accountList);
                            }
                        }
                    }
                    else if (this.conVars.context == CONTEXT_INFOBAU){
                        for (Account acc : [SELECT Id, Ibau_Id__c, Infobau_Id__c FROM Account WHERE Infobau_Id__c IN :pr.involvedAccountsbyAccountExternalId.keySet()]) {
                            if(existingAccountsbyExternalId.keySet().contains(acc.Infobau_Id__c)){
                                List<Account> accountList = existingAccountsbyExternalId.get(acc.Infobau_Id__c);
                                accountList.add(acc);
                                existingAccountsbyExternalId.put(acc.Infobau_Id__c, accountList);
                            } else {
                                List<Account> accountList = new List<Account>{acc};
                                existingAccountsbyExternalId.put(acc.Infobau_Id__c, accountList);
                            }
                        }
                    }
                    for (BISProject bp : pr.projects) {
                        // build SF records out of parsed BIS Project data
                        handleBISProject(bp, pd, false, existingAccountsbyExternalId);
                    }
                    System.debug('########## RP Imported Projects External ID: ' + pd.importedProjectsByExternalId.size());
                    System.debug('########## RP Imported Projects BIS ID: ' + pd.importedProjectsByBISId.size());
                    System.debug('########## RP Imported Projects with Submission Results: ' + pd.importedSubResultsByExtIdByProjectExtId.size());
                    System.debug('########## RP Skipped Projects: ' + pd.skippedProjectsByExtId.size());

                    // check if skipped projects has already been imported in the past
                    if (!pd.skippedProjectsByExtId.isEmpty() || Test.isRunningTest()) {
                        List<BISProject> existingSkippedProjects = new List<BISProject>();

                        for (Project__c extPro : [SELECT Id, External_ID__c FROM Project__c WHERE External_ID__c IN :pd.skippedProjectsByExtId.keySet()]) {
                            existingSkippedProjects.add(pd.skippedProjectsByExtId.get(extPro.External_ID__c));
                        }

                        for (BISProject bp : existingSkippedProjects) {
                            // force import of skipped projects that has already been imported before
                            handleBISProject(bp, pd, true, existingAccountsbyExternalId);
                        }
                    }

                    if (!pd.importedProjectsByExternalId.isEmpty()) {
                        List<Project__c> existingProjects = new List<Project__c>();
                        // query existing project records
                        for (Project__c extPro : [SELECT Id, External_ID__c FROM Project__c WHERE External_ID__c IN :pd.importedProjectsByExternalId.keySet()]) {
                            Project__c receivedProject = pd.importedProjectsByExternalId.get(extPro.External_ID__c);
                            // set Id needed for update call
                            receivedProject.Id = extPro.Id;
                            // move existing project record into separate list
                            existingProjects.add(receivedProject);
                            // remove existing project records from map
                            pd.importedProjectsByExternalId.remove(extPro.External_ID__c);
                        }
                        if (this.conVars.context == CONTEXT_INFOBAU) {
                            //for infobau, check also for bis project id   
                            for (Project__c extPro : [SELECT Id, Project_ID_BIS__c FROM Project__c WHERE Project_ID_BIS__c IN :pd.importedProjectsByBISId.keySet() AND Exact_Source__c = 'infobau']) {
                                Project__c receivedProject = pd.importedProjectsByBISId.get(extPro.Project_ID_BIS__c);
                                // set Id needed for update call
                                receivedProject.Id = extPro.Id;
                                // move existing project record into separate list
                                existingProjects.add(receivedProject);
                                // remove existing project records from map
                                pd.importedProjectsByExternalId.remove(receivedProject.External_ID__c);
                            }
                        }
                        System.debug('########## RP existingProjects: ' + existingProjects.size());
                        System.debug('########## RP new projects: ' + pd.importedProjectsByExternalId.size());

                        // check if there is at least one new project record
                        if (!pd.importedProjectsByExternalId.isEmpty()) {
                            // query Queue
                            List<Group> grpList = [SELECT Id, Name, DeveloperName FROM Group WHERE Type = 'Queue' AND DeveloperName = 'Vertriebssteuerung' limit 1];
                            if (!grpList.isEmpty()) {
                                // set Queue 'Vertriebssteuerung' as Owner for new records
                                for (Project__c newProj : pd.importedProjectsByExternalId.values()) {
                                    newProj.OwnerId = grpList[0].Id;
                                }
                            }
                            else {
                                String errorMessage = 'Queue \'Vertriebssteuerung\' not found';
                                System.debug('########## RP Error: ' + errorMessage);
                                createErrorLog(errorMessage);
                            }
                        }

                        // Insert + Update Project records (Upsert not possible, because DMLOptions cannot be set for Upsert)
                        // set DMLOptions to bypass duplicate rule errors and cut too long string values
                        Database.DMLOptions dmlOptions = new Database.DMLOptions();
                        dmlOptions.allowFieldTruncation = true;
                        dmlOptions.optAllOrNone = false;
                        dmlOptions.DuplicateRuleHeader.AllowSave = true; 

                        // Update existing Projects
                        if (!existingProjects.isEmpty()) {
                            Database.SaveResult[] projectUpdateResult = Database.update(existingProjects, dmlOptions);
                            processProjectSaveErrors(existingProjects, projectUpdateResult);
                        }

                        Set<String> projectExtIdsFailedToInsert = new Set<String>();
                        // Insert new Projects (External Id does not exist)
                        if (!pd.importedProjectsByExternalId.isEmpty()) {
                            if (testError && this.conVars.context == CONTEXT_IBAU_DE) {
                                // enforce error to test error handling
                                pd.importedProjectsByExternalId.values()[0].Project_Address__CountryCode__s = 'Invalid';
                            }
                            List<Project__c> newProjects = pd.importedProjectsByExternalId.values();
                            Database.SaveResult[] projectInsertResult = Database.insert(newProjects, dmlOptions);
                            projectExtIdsFailedToInsert = processProjectSaveErrors(newProjects, projectInsertResult);
                        }

                        // Upsert Submission_Result__c records
                        if (!pd.importedSubResultsByExtIdByProjectExtId.isEmpty()) {
                            List<Submission_Result__c> srToUpsert = new List<Submission_Result__c>();
                            // skip records where parent project record failed to insert
                            for (String projectExtId : pd.importedSubResultsByExtIdByProjectExtId.keySet()) {
                                if (!projectExtIdsFailedToInsert.contains(projectExtId)) {
                                    srToUpsert.addAll(pd.importedSubResultsByExtIdByProjectExtId.get(projectExtId).values());
                                }
                            }

                            if (testError) {
                                // enforce error to test error handling
                                srToUpsert[0].Project__c = null;
                            }
                            Database.UpsertResult[] srUpsertResult = Database.upsert(srToUpsert, Submission_Result__c.Fields.External_ID__c, false);
                            // check results
                            Integer i = 0;
                            for (Database.UpsertResult ur : srUpsertResult) {
                                if (!ur.isSuccess()) {
                                    this.conVars.srErrorsOccurred = true;

                                    String errorMessage = 'Error while saving imported Submission_Result__c record with External Id: ' + srToUpsert[i].External_ID__c;
                                    String exceptionMessage = ur.getErrors()[0].getStatusCode() + ': ' + ur.getErrors()[0].getMessage();

                                    String recId = ur.getId();
                                    if (String.isBlank(recId)) {
                                        recId = 'Submission_Result__c.External_ID__c: ' + srToUpsert[i].External_ID__c;
                                    }

                                    System.debug('########## RP Error: ' + exceptionMessage);
                                    createErrorLog(exceptionMessage, errorMessage, recId);
                                }
                                i++;
                            }
                        }

                        // only include handling of involved accounts if setting is set to true
                        if(this.conVars.handleInvolvedAccounts){
                            //Upsert Account_Lead__c records
                            if(!pd.importedAccountLeadsByExtIdByProjectExtId.isEmpty()) {
                                Map<String,Account_Lead__c> accountLeadstoUpsertByExternalID = new Map<String,Account_Lead__c>();
                                // skip records where parent project record failed to insert
                                for (String projectExtId : pd.importedAccountLeadsByExtIdByProjectExtId.keySet()) {
                                    if(!projectExtIdsFailedToInsert.contains(projectExtId)) {
                                        accountLeadstoUpsertByExternalID.putAll(pd.importedAccountLeadsByExtIdByProjectExtId.get(projectExtId));
                                    }
                                }
                                List<Database.UpsertResult> srUpsertResultAccountLeads = new List<Database.UpsertResult>();

                                if (this.conVars.context == CONTEXT_IBAU_DE) {
                                    srUpsertResultAccountLeads = Database.upsert(accountLeadstoUpsertByExternalID.values(), Account_Lead__c.Fields.Ibau_Id__c, false);
                                }
                                else if (this.conVars.context == CONTEXT_INFOBAU){
                                    srUpsertResultAccountLeads = Database.upsert(accountLeadstoUpsertByExternalID.values(), Account_Lead__c.Fields.Infobau_Id__c, false);
                                }

                                // check results
                                Integer i = 0;
                                for (Database.UpsertResult ur : srUpsertResultAccountLeads) {
                                    if (!ur.isSuccess()) {
                                        this.conVars.srErrorsOccurred = true;

                                        String errorExternalID = this.conVars.context == CONTEXT_INFOBAU ? accountLeadstoUpsertByExternalID.values()[i].Infobau_Id__c : accountLeadstoUpsertByExternalID.values()[i].Ibau_Id__c;
                                        String errorMessage = 'Error while saving imported Account_Lead__c record with External Id: ' + errorExternalID;
                                        String exceptionMessage = ur.getErrors()[0].getStatusCode() + ': ' + ur.getErrors()[0].getMessage();

                                        String recId = ur.getId();
                                        if (String.isBlank(recId)) {
                                            recId = 'Account_Lead__c.External_ID__c: ' + errorExternalID;
                                        }

                                        System.debug('########## RP Error: ' + exceptionMessage);
                                        createErrorLog(exceptionMessage, errorMessage, recId);
                                    }
                                    i++;
                                }
                            }

                            if(!pd.importedInvolvedAccountsByExtIdByProjectExtId.isEmpty()){

                                //create Project Account and Project Account Lead relations
                                if (this.conVars.context == CONTEXT_IBAU_DE) {
                                    for (Account_Lead__c accLead : [SELECT Id, Ibau_Id__c, Infobau_Id__c FROM Account_Lead__c WHERE Ibau_Id__c IN :pr.involvedAccountsbyAccountExternalId.keySet()]) {
                                        existingAccountLeadsbyExternalId.put(accLead.Ibau_Id__c, accLead);
                                    }
                                }
                                else if (this.conVars.context == CONTEXT_INFOBAU){
                                    for (Account_Lead__c accLead : [SELECT Id, Ibau_Id__c, Infobau_Id__c FROM Account_Lead__c WHERE Infobau_Id__c IN :pr.involvedAccountsbyAccountExternalId.keySet()]) {
                                        existingAccountLeadsbyExternalId.put(accLead.Infobau_Id__c, accLead);
                                    }
                                }

                                for (Project__c extPro : [SELECT Id, External_ID__c FROM Project__c WHERE External_ID__c IN :pr.projectExternalIds]) {
                                    existingProjectsbyExternalId.put(extPro.External_ID__c, extPro);
                                }

                                List<BISImportParse.InvolvedAccount> involvedAccountstoUpsert = new List<BISImportParse.InvolvedAccount>();
                                // skip records where parent project record failed to insert
                                for (String projectExtId : pd.importedInvolvedAccountsByExtIdByProjectExtId.keySet()) {
                                    if (!projectExtIdsFailedToInsert.contains(projectExtId)) {
                                        involvedAccountstoUpsert.addAll(pd.importedInvolvedAccountsByExtIdByProjectExtId.get(projectExtId).values());
                                    }
                                }

                                ProjectAccountRelation projAccRelationClass = createAccountProjectRelation(involvedAccountstoUpsert, existingAccountsbyExternalId, existingAccountLeadsbyExternalId, existingProjectsbyExternalId);

                                System.debug('########## RP New Project Account Relations: ' + projAccRelationClass.projectAccRelations.size());
                                System.debug('########## RP New Project Account Lead Relations: ' + projAccRelationClass.projectAccLeadRelations.size());
                                Database.UpsertResult[] srUpsertResultProjectAccountRelations = Database.upsert(projAccRelationClass.projectAccRelations, Project_Account_Relation__c.Fields.External_ID__c, false);

                                Integer i = 0;
                                for (Database.UpsertResult sr : srUpsertResultProjectAccountRelations) {
                                    if (!sr.isSuccess()) {
                                        this.conVars.srErrorsOccurred = true;
                                        String errorMessage = 'Error while saving imported Project_Account_Relation__c record with External ID: ' + projAccRelationClass.projectAccRelations[i].External_ID__c;
                                        String exceptionMessage = sr.getErrors()[0].getStatusCode() + ': ' + sr.getErrors()[0].getMessage();

                                        String recId = sr.getId();
                                        if (String.isBlank(recId)) {
                                            recId = 'Project_Account_Relation__c.External_ID__c: ' + projAccRelationClass.projectAccRelations[i].External_ID__c;
                                        }

                                        System.debug('########## RP Error: ' + exceptionMessage);
                                        createErrorLog(exceptionMessage, errorMessage, recId);
                                    }
                                    i++;
                                }

                                Database.UpsertResult[] srUpsertResultProjectAccountLeadRelations = Database.upsert(projAccRelationClass.projectAccLeadRelations, Project_Account_Lead_Relation__c.Fields.External_ID__c, false);

                                i = 0;
                                for (Database.UpsertResult sr : srUpsertResultProjectAccountLeadRelations) {
                                    if (!sr.isSuccess()) {
                                        this.conVars.srErrorsOccurred = true;

                                        String errorMessage = 'Error while saving imported Project_Account_Lead_Relation__c record with External ID: ' + projAccRelationClass.projectAccLeadRelations[i].External_ID__c;
                                        String exceptionMessage = sr.getErrors()[0].getStatusCode() + ': ' + sr.getErrors()[0].getMessage();

                                        String recId = sr.getId();
                                        if (String.isBlank(recId)) {
                                            recId = 'Project_Account_Lead_Relation__c.External_ID__c: ' + projAccRelationClass.projectAccLeadRelations[i].External_ID__c;
                                        }

                                        System.debug('########## RP Error: ' + exceptionMessage);
                                        createErrorLog(exceptionMessage, errorMessage, recId);
                                    }
                                    i++;
                                }
                            }
                        }
                    }
                }

                // delete projects not needed anymore
                if (!pr.projectExtIdToDelete.isEmpty() || Test.isRunningTest()) {
                    // query project and child project records to be deleted
                    List<Project__c> projectsToDelete = [SELECT Id, External_ID__c 
                                                            FROM Project__c 
                                                            WHERE (External_ID__c IN :pr.projectExtIdToDelete 
                                                                OR Main_Project__r.External_ID__c IN :pr.projectExtIdToDelete)];
                    System.debug('########## RP projectsToDelete: ' + projectsToDelete.size());

                    if (!projectsToDelete.isEmpty()) {
                        Database.DeleteResult[] delResult = Database.delete(projectsToDelete, false);
                        // check results
                        Integer i = 0;
                        for (Database.DeleteResult dr : delResult) {
                            if (!dr.isSuccess()) {
                                this.conVars.projectErrorsOccurred = true;
                                Id recId = dr.getId();
                                String errorMessage = 'Error while deleting Project record with Id: ' + recId;
                                String exceptionMessage = dr.getErrors()[0].getStatusCode() + ': ' + dr.getErrors()[0].getMessage();

                                System.debug('########## RP Error: ' + exceptionMessage);
                                createErrorLog(exceptionMessage, errorMessage, recId);
                            }
                            i++;
                        }
                    }
                }

                Boolean jobFinished = false;
                // check if data has been received for current page
                if (receivedCount > 0) {
                    // check if there are more projects to import
                    if (this.conVars.projectsReceived < pr.total) {
                        BISProjectImport projectImport = new BISProjectImport(this.conVars);
                        //System.enqueueJob(projectImport); 
                        if(!Test.isRunningTest()) {
                            UTLQueueableUtility.enqueueJob(projectImport); 
                        }   
                    }
                    else {
                        jobFinished = true;
                    }
                }
                else {
                    jobFinished = true;

                    // check if total number is greater than number of project items received
                    if (pr.total > this.conVars.projectsReceived) {
                        String errorMessage = 'Total number of available projects is greater than projects received from BIS.';
                        errorMessage += '\nTotal: ' + pr.total + ' \nReceived: ' + this.conVars.projectsReceived;
                        errorMessage += '\n\nContext: ' + this.conVars;
                        System.debug('########## RP Error: ' + errorMessage);
                        createErrorLog(errorMessage);
                    }
                }

                if (jobFinished) {
                    // update timestamp
                    BIS_Project_Import_Config__c conf = BIS_Project_Import_Config__c.getOrgDefaults();
                    try {
                        conf.put(timestampFieldNamesByContext.get(this.conVars.context), Decimal.valueOf(this.conVars.newUpdateTime));
                        upsert conf;
                    }
                    catch (Exception e) {
                        System.debug('########## RP Exception: ' + e.getMessage());
                        String errorMessage = 'Error while updating Last Import value in Custom Setting \'BIS_Project_Import_Config__c\'';
                        createErrorLog(e, errorMessage, conf.Id);
                    }
                }
            }
            else {
                try {
                    // start next attempt
                    BISProjectImport projectImport = new BISProjectImport(this.conVars, true);
                    if (!Test.isRunningTest()) {
                        //System.enqueueJob(projectImport);
                        UTLQueueableUtility.enqueueJob(projectImport); 
                    }
                }
                catch (Exception e) {
                    String errorMessage = 'Project import request error for: ' + this.conVars.context + '\nStatus Code: ' + res.getStatusCode() + '\nBody: ' + res.getBody();
                    errorMessage += '\n\nContext: ' + this.conVars;
                    System.debug('########## RP Error: ' + errorMessage);
                    createErrorLog(errorMessage);
                }
            }
        }
        catch (Exception e) {
            System.debug('########## RP Exception: ' + e.getMessage());
            createErrorLog(e, e.getMessage(), null);
        }

        // insert error logs
        UTLErrorLog.insertErrorLogs(this.errorLogs.values(), CLASSNAME);

        // send email notification if configured
        Set<String> errorEmailsAddresses;
        // get email adresses from custom setting
        BIS_Project_Import_Config__c errorConf = BIS_Project_Import_Config__c.getInstance();
        if (String.isNotBlank(errorConf.Error_Emails__c)) {
            errorEmailsAddresses = new Set<String>(errorConf.Error_Emails__c.split(','));
        }
        if ((errorEmailsAddresses != null && ! errorEmailsAddresses.isEmpty()) || Test.isRunningTest()) {
            UTLErrorLog.prepareAndSendErrorEmail(this.errorLogs.values(), CLASSNAME, errorEmailsAddresses);
        }
    }

    /**
     * Helper method to handle the parsed BIS Project data (build SF records).
     */
    private void handleBISProject(BISProject bp, ProjectData pd, Boolean ignoreImportCriteria, Map<String, List<Account>> existingAccountsbyExternalId) {
        Map<String, Object> projValues = bp.project;
        if (projValues != null) {
            // skip projects where country is not Germany ('D' or 'DE' or 'GER')
            if (projValues.get('Project_Address__CountryCode__s') != 'DE' && projValues.get('Project_Address__CountryCode__s') != 'D' && projValues.get('Project_Address__CountryCode__s') != 'GER') {
                System.debug('#### Skipped CountryCode: ' + projValues.get('Project_Address__CountryCode__s'));
                return;
            }
        
            // get external Id
            String projExtId = (String) projValues.get('External_ID__c');
            String projBISId = '';
            if (this.conVars.context == CONTEXT_INFOBAU) {
                projBISId = (String) projValues.get('BIS_Id__c');
            }

             // get start and end date
             Date constructionStartDate = parseDate((String) projValues.get('Project_Construction_Start__c'), true);
             Date constructionEndDate = parseDate((String) projValues.get('Project_Construction_End__c'), true);
             String constructionStartDateString = (String) projValues.get('Project_Construction_Start__c');
             String constructionSubmissionDateString = (String) projValues.get('Submission_Date__c');
 
             Boolean skipProject = false;
             // filter out projects by volume and startdate
             if (!ignoreImportCriteria) {
                 if (this.conVars.context == CONTEXT_INFOBAU) {
                     //if country code is 'GER', overwrite with 'DE' to make sure country code matches picklist
                     if(projValues.get('Project_Address__CountryCode__s') == 'GER'){
                         projValues.put('Project_Address__CountryCode__s','DE');
                     }
 
                     // Infobau: skip all projects with startdate >= 01.01.2022 that don't have an empty startdate or startdate 1.1.1970
                     if ((!(constructionStartDate >= Date.newInstance(2022, 1, 1))) && !(constructionStartDateString.startsWith('0000-00-00')) && !(String.isBlank(constructionStartDateString)) && !(constructionStartDateString.startsWith('1970-01-01'))){
                         skipProject = true;
                     }
 
                     //for projects with 01/01/1970 as a placeholder for enddate, overwrite with null
                     if (constructionEndDate == Date.newInstance(1970, 1, 1)){
                         projValues.put('Project_Construction_End__c',null);
                     }
 
                     //for projects with missing startdate or 01/01/1970 as a placeholder for startdate, overwrite with submission date
                     if(String.isBlank(constructionStartDateString) || constructionStartDateString.startsWith('0000-00-00') || constructionStartDateString.startsWith('1970-01-01')){
                         projValues.put('Project_Construction_Start__c',projValues.get('Submission_Date__c'));
                     }
 
                     //update variable for possible changes before
                     constructionStartDateString = (String) projValues.get('Project_Construction_Start__c');
 
                     //if startdate is still blank or 0000-00-00 or 01/01/1970, overwrite with placeholder
                     if(String.isBlank(constructionStartDateString) || constructionStartDateString.startsWith('0000-00-00') || constructionStartDateString.startsWith('1970-01-01')){
                         projValues.put('Project_Construction_Start__c',this.conVars.startDatePlaceholder);
                     }
                 }
                 else if (this.conVars.context == CONTEXT_IBAU_DE) {
                     //for projects with missing startdate or 01/12/2049 as a placeholder, overwrite with placeholder
                     if (constructionStartDateString == null || constructionStartDateString.startsWith('0000-00-00') || constructionStartDateString.startsWith('2049-12-01') || String.isBlank(constructionStartDateString)){
                         projValues.put('Project_Construction_Start__c',this.conVars.startDatePlaceholder);
                     }

                    Decimal totalVolume = (Decimal) projValues.get('Total_Volume__c');
                    if (totalVolume != null) {
                        //    > 100 Mio EUR: all Projects
                        // 50 - 100 Mio EUR: all Projects with startdate >= 01.01.2018
                        //     < 50 Mio EUR: all Projects with startdate >= 01.01.2020
                        if (!(
                            totalVolume > 100000000 || 
                            (totalVolume >= 50000000 && totalVolume <= 100000000 && constructionStartDate >= Date.newInstance(2018, 1, 1)) || 
                            (totalVolume < 50000000 && constructionStartDate >= Date.newInstance(2020, 1, 1)) )) {
                                skipProject = true;
                        }
                    }
                    else {
                        skipProject = true;
                    }
                }
            }

            if (skipProject) {
                // SF-1111: collect skipped ibau projects
                if (this.conVars.context == CONTEXT_IBAU_DE && String.isNotBlank(projExtId)) {
                    pd.skippedProjectsByExtId.put(projExtId, bp);
                }

                return;
            }

            // check if external id is set
            if (String.isBlank(projExtId)) {
                String errorMessage = 'Missing External Id (External_ID__c) for Project with Name \'' + projValues.get('Name') + '\' -> Skip Record';
                System.debug('########## RP Error: ' + errorMessage);
                createErrorLog(errorMessage, null);
                return;
            }

            // create project record to upsert
            Project__c proj = new Project__c();

            // set default values
            proj.Project_Source__c = '29'; // 29 -> Construction Information Systems
            proj.Core_Source_System__c = 'BIS';
            proj.Project_Type__c = 'Construction Projects';

            String projSource = (String) projValues.get('Exact_Source__c');

            Set<String> dateFields = new Set<String>{'Project_Construction_Start__c','Project_Construction_End__c','Submission_Date__c'};

            // set fields (JSON attribute names equals field API names)
            for (String fieldname : projValues.keySet()) {
                //skip helper Id field 
                if(fieldname != 'BIS_Id__c'){
                    // reset field
                    proj.put(fieldname, null);

                    // handle fields that need special logic
                    if (fieldname == 'Name') {
                        // check if Name is longer than 80 characters
                        String projectName = (String) projValues.get(fieldname);
                        if (projectName.length() > 80) {
                            projectName = projectName.left(77) + '...';
                        }
                        proj.Name = projectName;
                    }
                    else if (dateFields.contains(fieldname)) {
                        Date parsedDate = parseDate((String) projValues.get(fieldname), false);
                        proj.put(fieldname, parsedDate);
                    }
                    else if ((fieldname == 'Project_Address__CountryCode__s' || fieldname == 'Project_Address__StateCode__s') && projSource == 'iBau') {
                        if (fieldname == 'Project_Address__CountryCode__s') {
                            // handle mapping for iBau Countries
                            String countryValue = (String) projValues.get(fieldname);
                            if (countryValue != null) {
                                countryValue = countryValue.trim();
                            }
                            if (ibauCountryCodesToSF.containsKey(countryValue)) {
                                proj.put(fieldname, ibauCountryCodesToSF.get(countryValue));
                            }
                            else if (String.isNotBlank(countryValue)) {
                                String errorMessage = 'No mapping found for Country value \'' +  countryValue + '\'';
                                System.debug('########## RP Error: ' + errorMessage);
                                createErrorLog(errorMessage, 'Project__c.External_ID__c: ' + projExtId);
                            }
                        }
                        else {
                            // handle mapping for iBau States
                            String stateValue = (String) projValues.get(fieldname);
                            if (stateValue != null) {
                                stateValue = stateValue.trim();
                            }
                            if (ibauStateCodesToSF.containsKey(stateValue)) {
                                proj.put(fieldname, ibauStateCodesToSF.get(stateValue));
                            }
                            else if (String.isNotBlank(stateValue)) {
                                String errorMessage = 'No mapping found for State value \'' +  stateValue + '\'';
                                System.debug('########## RP Error: ' + errorMessage);
                                createErrorLog(errorMessage, 'Project__c.External_ID__c: ' + projExtId);
                            }
                        }
                    }
                    else if (fieldname == 'Project_Address__StateCode__s' && projSource == 'infoBau') {
                        // check if there is a mapping for the current infobau State
                        String stateValue = (String) projValues.get(fieldname);
                        if (stateValue != null) {
                            stateValue = stateValue.trim();
                        }
                        if (infobauStateCodesToSF.containsKey(stateValue)) {
                            proj.put(fieldname, infobauStateCodesToSF.get(stateValue));
                        }
                        else {
                            // skip 'AT' (used for projects with country 'AT')
                            if (stateValue != 'AT') {
                                proj.put(fieldname, stateValue);
                            }
                        }
                    }
                    else if (fieldname == 'Project_Construction_Progress__c' && projSource == 'infoBau') {
                        String sourceValue = (String) projValues.get(fieldname);
                        if (sourceValue == 'Ausschreibung') {
                            // set 'Planing'
                            proj.put(fieldname, '3');
                        }
                        else if (sourceValue == 'Submissionsergebnis' || sourceValue == 'Vergabemeldung') {
                            // set 'Shortly before start'
                            proj.put(fieldname, '4');
                        }
                        else if (sourceValue == 'InfoPlan') {
                            // set 'Pre Planing'
                            proj.put(fieldname, '2');
                        }
                        else {
                            String errorMessage = 'No Project_Construction_Progress__c mapping found for source value \'' +  sourceValue + '\'';
                            System.debug('########## RP Error: ' + errorMessage);
                            createErrorLog(errorMessage, 'Project__c.External_ID__c: ' + projExtId);
                        }
                    }
                    else {
                        proj.put(fieldname, projValues.get(fieldname));
                    }
                }
            }

            pd.importedProjectsByExternalId.put(projExtId, proj);
            if (this.conVars.context == CONTEXT_INFOBAU) {
                pd.importedProjectsByBISId.put(projBISId, proj);
            }

            // infoBau: handle also submission results
            if (this.conVars.context == CONTEXT_INFOBAU) {
                List<Map<String, Object>> srObjects = bp.submissionResults;
                if (srObjects != null && ! srObjects.isEmpty()) {
                    for (Map<String, Object> srValues : srObjects) {
                        // create Submission_Result__c record to upsert
                        Submission_Result__c sr = new Submission_Result__c();
                        String srExtId = (String) srValues.get('External_ID__c');
                        String projectExtId;

                        // check if external id is set
                        if (String.isBlank(srExtId)) {
                            String errorMessage = 'Missing External Id (External_ID__c) for Submission Result of Company \'' + srValues.get('Company__c') + '\' -> Skip Record';
                            System.debug('########## RP Error: ' + errorMessage);
                            createErrorLog(errorMessage);
                            continue;
                        }

                        // set fields (JSON attribute names equals field API names)
                        for (String fieldname : srValues.keySet()) {
                            // relate parent Project by External Id
                            if (fieldname == 'Project__c') {
                                projectExtId = (String) srValues.get(fieldname);
                                sr.Project__r = new Project__c(External_ID__c = projectExtId);
                            }
                            else {
                                sr.put(fieldname, srValues.get(fieldname));
                            }
                        }

                        if (!pd.importedSubResultsByExtIdByProjectExtId.containsKey(projectExtId)) {
                            pd.importedSubResultsByExtIdByProjectExtId.put(projectExtId, new Map<String, Submission_Result__c>());
                        }

                        pd.importedSubResultsByExtIdByProjectExtId.get(projectExtId).put(srExtId, sr);
                    }
                }
            }

            // handle involved Accounts in the same way subresults are handled
            List<BISImportParse.InvolvedAccount> involvedAccounts = bp.involvedAccounts;
            if (involvedAccounts != null && ! involvedAccounts.isEmpty()) {
                for(BISImportParse.InvolvedAccount involvedAcc : involvedAccounts){
                    //store all involved Accounts by Project and their external ID
                    String alExtId = involvedAcc.accountId;
                    String projectID = involvedAcc.projectExternalId;

                    if (!pd.importedInvolvedAccountsByExtIdByProjectExtId.containsKey(projectID)) {
                        pd.importedInvolvedAccountsByExtIdByProjectExtId.put(projectID, new Map<String, BISImportParse.InvolvedAccount>());
                    }

                    pd.importedInvolvedAccountsByExtIdByProjectExtId.get(projectID).put(alExtId, involvedAcc);

                    //if an account does not yet exist, create an account lead record
                    if(!existingAccountsbyExternalId.keySet().contains(involvedAcc.accountId)){
                        Account_Lead__c accLead = createAccountLead(involvedAcc);
                        
                        if (!pd.importedAccountLeadsByExtIdByProjectExtId.containsKey(projectID)) {
                            pd.importedAccountLeadsByExtIdByProjectExtId.put(projectID, new Map<String, Account_Lead__c>());
                        }

                        pd.importedAccountLeadsByExtIdByProjectExtId.get(projectID).put(alExtId, accLead);
                    }

                    

                }
            }
        }
        else {
            System.debug('########## RP projValues is null: ' + bp);
        }
    }

    private Account_Lead__c createAccountLead(BISImportParse.InvolvedAccount involvedAcc){
        Account_Lead__c accLead = new Account_Lead__c();
        accLead.Name = involvedAcc.name;
        accLead.Address__Street__s = involvedAcc.street;
        accLead.Address__PostalCode__s = involvedAcc.postcode;
        accLead.Address__City__s = involvedAcc.town;

        if(involvedAcc.countrycode == 'GER' || involvedAcc.countrycode == 'D' || involvedAcc.countrycode == 'DE'){
            accLead.Address__CountryCode__s = 'DE';
        }

        accLead.Email__c = involvedAcc.email;
        accLead.Fax__c = involvedAcc.fax;
        accLead.Phone__c = involvedAcc.phone;
        accLead.Source_System__c = 'BIS';
        accLead.Source_System_Exact__c = involvedAcc.exactSource;
        accLead.Website__c = involvedAcc.website;

        if(involvedAcc.exactSource == 'infobau'){
            accLead.Infobau_Id__c = involvedAcc.accountId;
        }
        else if(involvedAcc.exactSource == 'ibau'){
            accLead.Ibau_Id__c = involvedAcc.accountId;
        }
        return accLead; 
    }

    private ProjectAccountRelation createAccountProjectRelation(List<BISImportParse.InvolvedAccount> involvedAccounts, Map<String,List<Account>> existingAccountsbyExternalId, Map<String,Account_Lead__c> existingAccountLeadsbyExternalId, Map<String,Project__c> existingProjectsbyExternalId){
        ProjectAccountRelation projAccRelationClass = new ProjectAccountRelation();
        projAccRelationClass.projectAccRelations = new List<Project_Account_Relation__c>();
        projAccRelationClass.projectAccLeadRelations = new List<Project_Account_Lead_Relation__c>();

        Map<String,Project_Account_Relation__c> projAccRelationByExternalID = new Map<String,Project_Account_Relation__c>();
        Map<String,Project_Account_Lead_Relation__c> projAccLeadRelationByExternalID = new Map<String,Project_Account_Lead_Relation__c>();

        for(BISImportParse.InvolvedAccount involvedAcc : involvedAccounts){
            if(existingAccountsbyExternalId.keySet().contains(involvedAcc.accountId)){
                for(Account acc : existingAccountsbyExternalId.get(involvedAcc.accountId)){
                    //create Project Account Relation
                    Project_Account_Relation__c projAccRelation = new Project_Account_Relation__c();
                    projAccRelation.External_ID__c = acc.Id + '_' + existingProjectsbyExternalId.get(involvedAcc.projectExternalId).Id;
                    projAccRelation.Account__c = acc.Id;
                    projAccRelation.Project__c = existingProjectsbyExternalId.get(involvedAcc.projectExternalId).Id;
                    projAccRelation.Account_Role__c = involvedAcc.accountRole;
                    projAccRelationByExternalID.put(projAccRelation.External_ID__c, projAccRelation);
                }
            } 
            else if(existingAccountLeadsbyExternalId.keySet().contains(involvedAcc.accountId)){
                if(existingProjectsbyExternalId.get(involvedAcc.projectExternalId) != null){
                    //create Project Account Lead Relation
                    Project_Account_Lead_Relation__c projAccLeadRelation = new Project_Account_Lead_Relation__c();
                    projAccLeadRelation.External_ID__c = existingAccountLeadsbyExternalId.get(involvedAcc.accountId).Id + '_' + existingProjectsbyExternalId.get(involvedAcc.projectExternalId).Id;
                    projAccLeadRelation.Account_Lead__c = existingAccountLeadsbyExternalId.get(involvedAcc.accountId).Id;
                    projAccLeadRelation.Project__c = existingProjectsbyExternalId.get(involvedAcc.projectExternalId).Id;
                    projAccLeadRelation.Account_Role__c = involvedAcc.accountRole;
                    projAccLeadRelationByExternalID.put(projAccLeadRelation.External_ID__c, projAccLeadRelation);
                }
            }
        }

        projAccRelationClass.projectAccRelations = projAccRelationByExternalID.values();
        projAccRelationClass.projectAccLeadRelations = projAccLeadRelationByExternalID.values();

        return projAccRelationClass;
    }



    /**
     * Get ibau Country Code mappings from custom metadata type
     */
    public static Map<String, String> ibauCountryCodesToSF {
        get {
            if (ibauCountryCodesToSF == null) {
                ibauCountryCodesToSF = new Map<String, String>();
                for (Country_Code_Mapping__mdt countryCodeMappping : Country_Code_Mapping__mdt.getAll().values()) {
                    if (String.isNotBlank(countryCodeMappping.ibau__c)) {
                        ibauCountryCodesToSF.put(countryCodeMappping.ibau__c, countryCodeMappping.SF__c);
                    }
                }
            }
            return ibauCountryCodesToSF;
        }
        set;
    }

    /**
     * Get ibau State Code mappings from custom metadata type
     */
    public static Map<String, String> ibauStateCodesToSF {
        get {
            if (ibauStateCodesToSF == null) {
                ibauStateCodesToSF = new Map<String, String>();
                for (State_Code_Mapping__mdt stateCodeMappping : State_Code_Mapping__mdt.getAll().values()) {
                    if (String.isNotBlank(stateCodeMappping.ibau__c)) {
                        ibauStateCodesToSF.put(stateCodeMappping.ibau__c, stateCodeMappping.SF__c);
                    }
                }
            }
            return ibauStateCodesToSF;
        }
        set;
    }

    /**
     * Get infobau State Code mappings from custom metadata type
     */
    public static Map<String, String> infobauStateCodesToSF {
        get {
            if (infobauStateCodesToSF == null) {
                infobauStateCodesToSF = new Map<String, String>();
                for (State_Code_Mapping__mdt stateCodeMappping : State_Code_Mapping__mdt.getAll().values()) {
                    if (String.isNotBlank(stateCodeMappping.infobau__c)) {
                        for (String code : stateCodeMappping.infobau__c.split(',')) {
                            infobauStateCodesToSF.put(code, stateCodeMappping.SF__c);
                        }
                    }
                }
            }
            return infobauStateCodesToSF;
        }
        set;
    }

    /**
     * Helper method to simplfy errlor log creation.
     */
    @TestVisible
    private void createErrorLog(String exceptionMessage) {
        createErrorLog(exceptionMessage, null);
    }

    /**
     * Helper method to simplfy errlor log creation.
     */
    private void createErrorLog(String exceptionMessage, String recId) {
        createErrorLog(exceptionMessage, exceptionMessage, recId);
    }

    /**
     * Helper method to simplfy errlor log creation.
     */
    private void createErrorLog(String exceptionMessage, String errorMessage, String recId) {
        createErrorLog(new BISImportException(exceptionMessage), errorMessage, recId);
    }

    /**
     * Helper method to simplfy errlor log creation.
     */
    private void createErrorLog(Exception ex, String errorMessage, String recId) {
        // add import context 
        errorMessage = '['+this.conVars.context+'] ' + errorMessage;
        Core_Error_Log__c errorLog = UTLErrorLog.createErrorLogRecord(CLASSNAME, ex, errorMessage, recId, SOURCESYSTEM, true);
        this.errorLogs.put(errorLog.Core_CheckSum__c, errorLog);
    }

    /**
     * Parse 
     */
    private Date parseDate(String dateString, Boolean skip2049) {
        Date parsedDate;
        // '2049-12-01' is used as a placeholder and means that date is not specified yet
        if (String.isNotBlank(dateString) && ! dateString.startsWith('0000-00-00') && (!skip2049 || !dateString.startsWith('2049-12-01') )) {
            parsedDate = Date.valueOf(dateString);
        }
        return parsedDate;
    }

    /**
     * Used to collect errors from Database.SaveResult of Projects.
     */
    private Set<String> processProjectSaveErrors(List<Project__c> projDMLList, List<Database.SaveResult> saveResults) {
        Set<String> failedExternalIds = new Set<String>();

        // check results
        Integer i = 0;
        for (Database.SaveResult sr : saveResults) {
            if (!sr.isSuccess()) {
                this.conVars.projectErrorsOccurred = true;

                String extId = projDMLList[i].External_ID__c;
                if (String.isNotBlank(extId)) {
                    failedExternalIds.add(extId);
                }
                String errorMessage = 'Error while saving imported Project__c record with External Id: ' + extId;
                String exceptionMessage = sr.getErrors()[0].getStatusCode() + ': ' + sr.getErrors()[0].getMessage();

                String recId = sr.getId();
                if (String.isBlank(recId)) {
                    recId = 'Project__c.External_ID__c: ' + extId;
                }

                System.debug('########## RP exceptionMessage: ' + exceptionMessage);
                createErrorLog(exceptionMessage, errorMessage, recId);
            }
            i++;
        }

        return failedExternalIds;
    }

    /**
     * Method to URL encode strings and ensure that spaces are converted to '%20' instead '+'
     */
    private String urlEncodeSpacesAsPercentValue(String textToUrlEncode) {
        if (String.isNotBlank(textToUrlEncode)) {
            textToUrlEncode = textToUrlEncode.replaceAll(' ','___20___');
            textToUrlEncode = EncodingUtil.urlEncode(textToUrlEncode, 'UTF-8');
            textToUrlEncode = textToUrlEncode.replaceAll('___20___','%20');
        }

        return textToUrlEncode;
    }

    /**
     * Wrapper class for Project response values
     */
    public class BISProject {
        public Map<String, Object> project;
        public List<Map<String, Object>> submissionResults;
        public List<BISImportParse.InvolvedAccount> involvedAccounts;
        public Boolean doDelete = false;

        public Set<String> skippedAccountRoles;
    }

    /**
     * Wrapper class for Project relation values
     */
    public class ProjectAccountRelation{
        public List<Project_Account_Relation__c> projectAccRelations;
        public List<Project_Account_Lead_Relation__c> projectAccLeadRelations;
    }

    /**
     * Wrapper class for imported Project data
     */
    public class ProjectData {
        public Map<String, Project__c> importedProjectsByExternalId;
        public Map<String, Project__c> importedProjectsByBISId;
        public Map<String, Map<String, Submission_Result__c>> importedSubResultsByExtIdByProjectExtId;
        public Map<String, Map<String, Account_Lead__c>> importedAccountLeadsByExtIdByProjectExtId;
        public Map<String, Map<String,BISImportParse.InvolvedAccount>> importedInvolvedAccountsByExtIdByProjectExtId;
        // contains the BISProject data that has been skipped because of not matching the import criteria
        public Map<String, BISProject> skippedProjectsByExtId;

        public Set<String> skippedAccountRoles;

        /**
         * Constructor
         */
        public ProjectData() {
            this.importedProjectsByExternalId = new Map<String, Project__c>();
            this.importedProjectsByBISId = new Map<String, Project__c>();
            this.importedSubResultsByExtIdByProjectExtId = new Map<String, Map<String, Submission_Result__c>>();
            this.importedAccountLeadsByExtIdByProjectExtId = new Map<String, Map<String, Account_Lead__c>>();
            this.importedInvolvedAccountsByExtIdByProjectExtId = new Map<String, Map<String,BISImportParse.InvolvedAccount>>();
            this.skippedProjectsByExtId = new Map<String, BISProject>();

            this.skippedAccountRoles = new Set<String>();
        }
    }

    /**
     * Wrapper class for context values 
     */
    public class ContextVars {
        // current import context (e.g. infobau or ibau)
        public String context;

        // new timestamp value to be saved after successful import
        public Long newUpdateTime;

        // timestamp of last update request
        public Long lastUpdateTime;

        // the number of projects to be loaded per page
        public Integer pageSize;

        // the max number of request retry attempts per page (3 means initial attempt + 3 retry attempts)
        public Integer retryLimit;

        // the current request attempt for the current page (1 means initial attempt)
        public Integer requestAttempt;

        // request filter (json_query parameter value)
        public String requestFilter;

        // the page of the current run
        public Integer currentPage;

        // checkbox to either include involved accounts handling or not
        public Boolean handleInvolvedAccounts;

        // construction start date placeholder
        public String startDatePlaceholder;

        // the number of project items that have been received so far
        public Integer projectsReceived;
        
        // flags that indicate whether any error occurred during whole import
        public Boolean projectErrorsOccurred;
        public Boolean srErrorsOccurred;

        /**
         * Constructor
         */
        public ContextVars(String context) {
            this.context = context;
            this.currentPage = 1;
            this.requestAttempt = 1;
            this.projectsReceived = 0;
            this.projectErrorsOccurred = false;
            this.srErrorsOccurred = false;
            this.handleInvolvedAccounts = false;

            // set new timestamp value to be saved after successful import
            this.newUpdateTime = Datetime.now().getTime();
        }

        /**
         * 
         */
        public void setNextPage() {
            // increase page number
            this.currentPage++;
            // reset request attempt number
            this.requestAttempt = 1;
            // set new timestamp value (timestamp of last page will be saved after successful import)
            this.newUpdateTime = Datetime.now().getTime();
        }

        /**
         * 
         */
        public void setNextAttempt() {
            if (this.requestAttempt <= this.retryLimit) {
                this.requestAttempt++;
            }
            else {
                throw new BISImportException('Max number of request attempts exceeded.');
            }
        }
    }

    public class BISImportException extends Exception {}
}