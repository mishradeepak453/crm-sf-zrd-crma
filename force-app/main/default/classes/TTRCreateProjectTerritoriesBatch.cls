/**
 * SF-1058
 * Batch job to create missing Project Territories (Project_Territory__c).
 *
 * @group TTR Territories
 * @date 2023-05-04
 * @author rene.pienkoss@accenture.com
 */
public without sharing class TTRCreateProjectTerritoriesBatch implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    
    public static final String CLASSNAME = 'TTRCreateProjectTerritoriesBatch';
    public String query;
    public static Integer defaultBatchSize = 1000;

    // statistical values
    private Statistics stats;

    /** the list of errors handled during execution **/
    private List<Core_Error_Log__c> errorLogs;


    /**
     * Constructor
     */
    public TTRCreateProjectTerritoriesBatch() {
        this.stats = new Statistics();
        this.errorLogs = new List<Core_Error_Log__c>();
    }

    /**
     * The start method is called at the beginning of the batch Apex job.
     * This method returns the Database.QueryLocator that contains the records 
     * being passed into the job.
     * 
     * @param bc    Database.BatchableContext
     * 
     * @return Database.QueryLocator for Project__c records
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('########## RP TTRCreateProjectTerritoriesBatch: start');

        if (this.query == null) {
            // query Project__c
            this.query = 'SELECT Id '+
                            'FROM Project__c '+
                            //'WHERE Project_Address__PostalCode__s != null '+
                            'ORDER BY Project_Address__PostalCode__s';
        }

        return Database.getQueryLocator(this.query);
    }

    /**
     * The execute method is called for each batch of records passed to the method.
     * 
     * @param bc    Database.BatchableContext
     * @param scope List of Project__c records to be processed
     */
    public void execute(Database.BatchableContext bc, List<Project__c> scope) {
        System.debug('########## RP TTRCreateProjectTerritoriesBatch: execute: ' + scope.size());

        try {
            // query Projects and related Territories
            List<Project__c> projList = [SELECT Id, Project_Address__PostalCode__s, 
                                                (SELECT Id, Project__c, Territory_ID__c 
                                                    FROM Project_Territories__r)
                                            FROM Project__c 
                                            WHERE Id IN :scope];

            Set<String> postalCodes = new Set<String>();

            this.stats.projectCount += projList.size();

            // collect Postal Codes
            for (Project__c proj : projList) {
                if (proj.Project_Address__PostalCode__s != null) {
                    postalCodes.add(proj.Project_Address__PostalCode__s);
                }
                else {
                    this.stats.projectIdsWithoutPostalCode.add(proj.Id);
                }
            }

            // requst Territory data from API
            Map<String, List<SHRGraceAPI.SalesUnit>> salesUnitsbyPLZ;
            if ( ! Test.isRunningTest()) {
                salesUnitsbyPLZ = SHRGraceAPI.getSalesUnitsByPostalCodeList(
                    new List<String>(postalCodes)
                );
            }
            else {
                String testPLZ = TTRCreateProjectTerritoriesBatchTest.postalCode;
                String testResponse = '[{"businessarea":1,"salesunitid":"M035","salesunit":"Mietstation Jena","region":"0506","regionname":"03 Thüringen/Sachsen/Anhalt","companyid":"1","company":"ZRD","businessareaname":"Maschinen- & Ger\u00e4tevermietung"},{"businessarea":2,"salesunitid":"M453","salesunit":"Kompetenz-Center Containervermietung Jena","region":"MIU8","regionname":"Produkt-/Sonderbereiche","companyid":"1","company":"ZRD","businessareaname":"Raumsysteme"},{"businessarea":3,"salesunitid":"M403","salesunit":"Baustellen- und Verkehrssicherung Halle-Leipzig","region":"MIU7","regionname":"Produkt-/Sonderbereiche","companyid":"1","company":"ZRD","businessareaname":"Baustellen- und Verkehrssicherung"},{"businessarea":4,"salesunitid":"M762","salesunit":"Elektro & Energie Halle","region":"1313","regionname":"Produkt-/Sonderbereiche","companyid":"1","company":"ZRD","businessareaname":"Energie, Klima & Wasser"}]';

                salesUnitsbyPLZ = new Map<String, List<SHRGraceAPI.SalesUnit>>{
                    testPLZ => (List<SHRGraceAPI.SalesUnit>) JSON.deserialize(testResponse, List<SHRGraceAPI.SalesUnit>.class)
                };
            }

            List<Project_Territory__c> projTerrsToInsert = new List<Project_Territory__c>();

            // create missing Territories
            for (Project__c proj : projList) {
                // collect existing Territory Ids
                Set<String> existingTerrIds = new Set<String>();
                for (Project_Territory__c pt : proj.Project_Territories__r) {
                    existingTerrIds.add(pt.Territory_ID__c);
                }

                // create Territories
                if (salesUnitsbyPLZ.containsKey(proj.Project_Address__PostalCode__s)) {
                    this.stats.terrsReceivedCount += salesUnitsbyPLZ.get(proj.Project_Address__PostalCode__s).size();
                    this.stats.addProjectTerrCount(salesUnitsbyPLZ.get(proj.Project_Address__PostalCode__s).size());

                    if (salesUnitsbyPLZ.get(proj.Project_Address__PostalCode__s).size() < 4) {
                        this.stats.postalCodesWithLessThan4Terrs.add(proj.Project_Address__PostalCode__s);
                    }
                    else if (salesUnitsbyPLZ.get(proj.Project_Address__PostalCode__s).size() > 4) {
                        this.stats.postalCodesWithMoreThan4Terrs.add(proj.Project_Address__PostalCode__s);
                    }

                    for (SHRGraceAPI.SalesUnit su : salesUnitsbyPLZ.get(proj.Project_Address__PostalCode__s)) {
                        if ( ! existingTerrIds.contains(su.salesunitid)) {
                            this.stats.terrsCreatedCount++;
                            projTerrsToInsert.add(
                                new Project_Territory__c(
                                    Project__c = proj.Id,
                                    Territory_ID__c = su.salesunitid,
                                    Territory_Name__c = su.salesunit,
                                    Business_Area__c = String.valueOf(su.businessarea),
                                    Territory_Level_1__c = su.company,
                                    Territory_Level_2__c = su.regionname
                                )
                            );
                        }
                        else {
                            this.stats.terrsExistingCount++;
                        }
                    }
                }
                else {
                    this.stats.addProjectTerrCount(0);
                    this.stats.postalCodesWithoutTerrs.add(proj.Project_Address__PostalCode__s);
                    String errorMessage = 'No Territory data received for Postal Code: ' + proj.Project_Address__PostalCode__s;
                    this.errorLogs.add(UTLErrorLog.createErrorLogRecord(CLASSNAME, new HandledException(errorMessage), errorMessage, proj.Id));
                }
            }

            if ( ! projTerrsToInsert.isEmpty()) {
                Database.SaveResult[] ptInsertResult = Database.insert(projTerrsToInsert, false);
                // check results
                Integer i = 0;
                for (Database.SaveResult sr : ptInsertResult) {
                    if ( ! sr.isSuccess()) {
                        Id projId = projTerrsToInsert[i].Project__c;

                        String errorMessage = 'Error while inserting Project_Territory__c record with Territory_ID__c \'' + projTerrsToInsert[i].Territory_ID__c + '\' for Project: ' + projId;
                        String exceptionMessage = sr.getErrors()[0].getStatusCode() + ': ' + sr.getErrors()[0].getMessage();

                        System.debug('########## RP exceptionMessage: ' + exceptionMessage);
                        this.errorLogs.add(UTLErrorLog.createErrorLogRecord(CLASSNAME, new HandledException(exceptionMessage), errorMessage, projId));
                    }
                    i++;
                }
            }
        }
        catch (Exception e) {
            System.debug('########## RP Exception: ' + e.getMessage());
            this.errorLogs.add(UTLErrorLog.createErrorLogRecord(CLASSNAME, e, e.getMessage(), null));
        }
    }

    /**
     * The finish method is called after all batches are processed.
     * 
     * @param bc    Database.BatchableContext
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('########## RP TTRCreateProjectTerritoriesBatch: finish');
        
        //System.debug('########## RP stats: ' + this.stats);
        System.debug('########## RP projectCount: ' + this.stats.projectCount);
        System.debug('########## RP terrsReceivedCount: ' + this.stats.terrsReceivedCount);
        System.debug('########## RP terrsCreatedCount: ' + this.stats.terrsCreatedCount);
        System.debug('########## RP terrsExistingCount: ' + this.stats.terrsExistingCount);
        System.debug('########## RP projectCountByNumberOfTerrs: ' + this.stats.projectCountByNumberOfTerrs);
        System.debug('########## RP projectIdsWithoutPostalCode: ' + this.stats.projectIdsWithoutPostalCode);
        System.debug('########## RP postalCodesWithLessThan4Terrs: ' + this.stats.postalCodesWithLessThan4Terrs);
        System.debug('########## RP postalCodesWithoutTerrs: ' + this.stats.postalCodesWithoutTerrs);

        System.debug('########## RP errorLogs: ' + this.errorLogs.size());
        // insert error logs
        UTLErrorLog.insertErrorLogs(this.errorLogs, CLASSNAME);
    }

    /**
     * Wrapper class to collect statistical values
     */
    private class Statistics {
        private Integer projectCount;
        private Integer terrsReceivedCount;
        private Integer terrsCreatedCount;
        private Integer terrsExistingCount;
        private Map<Integer, Integer> projectCountByNumberOfTerrs;
        private Set<Id> projectIdsWithoutPostalCode;
        private Set<String> postalCodesWithMoreThan4Terrs;
        private Set<String> postalCodesWithLessThan4Terrs;
        private Set<String> postalCodesWithoutTerrs;

        /**
         * Constructor
         */
        public Statistics() {
            this.projectCount = 0;
            this.terrsReceivedCount = 0;
            this.terrsCreatedCount = 0;
            this.terrsExistingCount = 0;
            this.projectCountByNumberOfTerrs = new Map<Integer, Integer>();
            this.projectIdsWithoutPostalCode = new Set<Id>();
            this.postalCodesWithMoreThan4Terrs = new Set<String>();
            this.postalCodesWithLessThan4Terrs = new Set<String>();
            this.postalCodesWithoutTerrs = new Set<String>();
        }

        /**
         * Method to increase Project Count for the passed number of received Territories.
         * 
         * @param terrCount    the number of received Territories for the project
         */
        public void addProjectTerrCount(Integer terrCount) {
            if ( ! this.projectCountByNumberOfTerrs.containsKey(terrCount)) {
                this.projectCountByNumberOfTerrs.put(terrCount, 0);
            }
            this.projectCountByNumberOfTerrs.put(terrCount, projectCountByNumberOfTerrs.get(terrCount)+1);
        }
    }
}