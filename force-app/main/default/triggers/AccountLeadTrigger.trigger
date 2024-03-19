/**
 * Trigger for Account_Lead__c object.
 *
 * @version 2023-10-20	isabella.moos@accenture.com		creation
 */
trigger AccountLeadTrigger on Account_Lead__c (after update) {
    new SHRAccountLeadTriggerHandler().run();
}