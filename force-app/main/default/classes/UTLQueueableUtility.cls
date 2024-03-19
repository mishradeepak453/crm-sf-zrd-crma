/**
 * Utility class for queueable methods
 *
 * @author  isabella.moos@accenture.com
 *
 * @version 2023-10-27      isabella.moos@accenture.com     creation
 */
public with sharing class UTLQueueableUtility implements Queueable, Database.AllowsCallouts {
    Queueable[] payload;
    static UTLQueueableUtility self;
    UTLQueueableUtility(Queueable item) {
        payload = new Queueable[] { item };
    }
    public static Id enqueueJob(Queueable item) {
        if(!System.isQueueable()) {
            return System.enqueueJob(new UTLQueueableUtility(item));
        } else {
            if(Test.isRunningTest()) {
                return null;
            } else {
                self.payload.add(item);
                return null;
            }

        }
    }
    public void execute(QueueableContext context) {
        self = this;
        payload.remove(0).execute(context);
        if(!payload.isEmpty()) {
            System.enqueueJob(this);
        }
    }
}