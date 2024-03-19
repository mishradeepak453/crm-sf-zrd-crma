/**
 * Scheduler to execute GRSYAccCdcTriggerdBatch 
 * 
 * @author daniel.gette@zeppelin.com
 * 
 * @version 2022-10-12  daniel.gette@zeppelin.com   creation
 * @version 2023-03-24  miriam.ida.tyroller@accenture.com   adjusted logic to first check if scheduled job is already running before executing anew
 */
public with sharing class GRSYAccCronJob implements Schedulable {

    private static Integer BATCH_SIZE =  (Integer) GRACE_API_Config__c.getOrgDefaults().Batch_Size__c;

    public void execute(SchedulableContext context) {
        //check if scheduled job is already running 
        List<ApexClass> classList = [SELECT Id FROM ApexClass WHERE Name LIKE 'GRSYAccCdcTriggerdBatch' LIMIT 1]; 
        Id classId = classList[0].Id;
        AsyncApexJob[] jobs = [SELECT Id FROM AsyncApexJob WHERE Status = 'Processing' AND ApexClassId = : classId AND JobType = 'BatchApex'];

        //only execute new batch if scheduled job is not currently running 
        if (jobs==null || jobs.size()==0) {
            Database.executeBatch(new GRSYAccCdcTriggerdBatch(), BATCH_SIZE);
        }
        else {
            System.debug('Scheduled Job GRSYAccCdcTriggerdBatch is already running');
        }
    }

}