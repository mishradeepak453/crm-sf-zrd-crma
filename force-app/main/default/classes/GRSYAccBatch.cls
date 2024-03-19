/**
 * Batchable to retrieve accounts from Grace and process them in batches 
 * 
 * @author daniel.gette@zeppelin.com
 * 
 * @version 2023-10-04  daniel.gette@zeppelin.com   creation
 */
public with sharing class GRSYAccBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {
    public String query;

    public Database.QueryLocator start(Database.BatchableContext BC) {
        System.debug('Query executed in Batch' + query);

        GRACE_API_Config__c graceapiConfig = GRACE_API_Config__c.getOrgDefaults();
        graceapiConfig.Last_Retry_Errors__c = Datetime.now();
        update graceapiConfig;
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext context, List<SObject> sObjects) {
        List<Core_Error_Log__c> errorLogs = (List<Core_Error_Log__c>) sObjects;
        Set<String> customerNumbers = UTLCommons.filterStringFieldValues(
            errorLogs,
            Core_Error_Log__c.Core_External_System_Id__c
        );

        UTLTriggerHandler.bypass('SHRAccountTriggerHandler');

        System.debug(
            'Following Ids getting passed into batch: ' + String.join((Iterable<String>) customerNumbers, ',')
        );
        new GRSYAccService().processAccountList(customerNumbers);
    }

    public void finish(Database.BatchableContext BC) {
        UTLTriggerHandler.clearBypass('SHRAccountTriggerHandler');
    }
}