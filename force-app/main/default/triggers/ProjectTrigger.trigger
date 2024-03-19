/**
 * Trigger for Project__c object.
 *
 * @version 2023-10-18  isabella.moos@accenture.com     creation
 */
trigger ProjectTrigger on Project__c (before update) {
    new SHRProjectTriggerHandler().run();
}