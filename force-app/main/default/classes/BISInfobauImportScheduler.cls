/**
 * SF-647: Scheduler for Infobau projects import job (BISProjectImport).
 * 
 * @author  rene.pienkoss@accenture.com
 * 
 * @version 2021-12-02  rene.pienkoss@accenture.com     creation
 * @version 2023-10-30  isabella.moos@accenture.com     added exception for running test for SF-1205
 */
public class BISInfobauImportScheduler implements Schedulable {
    
    /**
     * The execute method is used to instantiate the class to be scheduled.
     */
    public void execute(SchedulableContext sc) {
        BISProjectImport projectImport = new BISProjectImport(BISProjectImport.CONTEXT_INFOBAU);
        if(Test.isRunningTest()) {
            System.enqueueJob(projectImport);
        } else {
            UTLQueueableUtility.enqueueJob(projectImport);
        }
    }
}