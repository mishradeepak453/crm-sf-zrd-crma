/**
 * Trigger for Project_Account_Lead_Relation__c object.
 *
 * @version 2023-10-20	isabella.moos@accenture.com		creation
 */
trigger ProjectAccountLeadRelationTrigger on Project_Account_Lead_Relation__c (after insert, after update, after delete, after undelete) {
    new SHRPALRTriggerHandler().run();
}