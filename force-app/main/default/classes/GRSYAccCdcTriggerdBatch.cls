/**
 * Batchable to retrieve account Ids on change from Grace and process changes in batches 
 * 
 * @author daniel.gette@zeppelin.com
 * 
 * @version 2023-03-16  daniel.gette@zeppelin.com   creation
 */
public with sharing class GRSYAccCdcTriggerdBatch implements Database.Batchable<Account>, Database.AllowsCallouts {

    private static Integer QUERY_LIMIT =  (Integer) GRACE_API_Config__c.getOrgDefaults().Query_Limit__c;

    public Iterable<Account> start(Database.BatchableContext param1) {
        List<Account> accountCustomerNumbers = SHRGraceAPI.getCdcAccountIdsV1(QUERY_LIMIT);
        System.debug( accountCustomerNumbers.size() + ' Account customer numbers getting fetched.');
        return accountCustomerNumbers;
    }

    public void execute(Database.BatchableContext context, List<Account> accountCustomerNumbers) {
        Set<String> coreCustomerNumbers = UTLCommons.filterStringFieldValues(accountCustomerNumbers, Account.Core_Customer_Number__c);

        System.debug(
                'Following Ids getting passed into batch: ' + String.join((Iterable<String>) accountCustomerNumbers, ',')
        );

        UTLTriggerHandler.bypass('SHRAccountTriggerHandler');

        new GRSYAccService().processAccountList(coreCustomerNumbers);
    }

    public void finish(Database.BatchableContext BC) {
        UTLTriggerHandler.clearBypass('SHRAccountTriggerHandler');
    }
}