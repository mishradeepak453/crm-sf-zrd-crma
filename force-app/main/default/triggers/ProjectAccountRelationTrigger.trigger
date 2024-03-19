/**
 * Trigger for Project_Account_Relation__c object.
 *
 * @version 2023-10-09	isabella.moos@accenture.com		creation
 */
trigger ProjectAccountRelationTrigger on Project_Account_Relation__c (after insert, after update, after delete, after undelete) {
    new SHRProjectAccountRelationTriggerHandler().run();
}