/**
 * SF-1014: Scheduler for infobau / ibau project deletion job (BISProjectDeletion)
 * 
 * @author  miriam.ida.tyroller@accenture.com
 * 
 * @version 2023-07-31  miriam.ida.tyroller@accenture.com     creation
 */
public class BISProjectDeletionBatchScheduler implements Schedulable {

    private static Integer BATCH_SIZE = (Integer) BIS_Project_Import_Config__c.getOrgDefaults().Deletion_Batch_Size__c;
    
    /**
     * The execute method is used to instantiate the class to be scheduled.
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new BISProjectDeletionBatch(), BATCH_SIZE);
    }
}