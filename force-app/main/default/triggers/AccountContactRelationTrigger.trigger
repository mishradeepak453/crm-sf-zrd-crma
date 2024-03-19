/**
 * Trigger for AccountContactRelation object.
 *
 * @version 2021-12-08	rene.pienkoss@accenture.com		creation
 */
trigger AccountContactRelationTrigger on AccountContactRelation (before delete) {

    if (Trigger.isBefore) {
        if (Trigger.isDelete) {
            // prevent deletion
            for (AccountContactRelation acr : Trigger.old) {
                acr.addError(Label.Prevent_Account_Contact_Deletion);
            }
        }
    }
}