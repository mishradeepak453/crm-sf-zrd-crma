/**
 * SF-911 Account-Sync mittels Grace-Aufruf
 * The CDC Account Endpoint for REST-Communication.
 *
 * @group GRSY - Grace Sync Account
 * @date 30.06.2022
 * @author daniel.gette@zepplin.com
 */
@RestResource(UrlMapping='/grace/cdc/v1/notify/account/*')
global with sharing class GRSYAccRESTResource {
    @HttpGet
    global static CDCResult doGet() {
        Integer batchSize = 150; // default

        String batchSizeQuery = RestContext.request.params.get('batchSize');
        if (!String.isBlank(batchSizeQuery)) {
            batchSize = Integer.valueOf(batchSizeQuery);
        }

        try {
            GRSYAccRESTResource.CDCResult cdcResult = new GRSYAccService().processCdcAccounts(batchSize);
            // Change response Code, when errors occurs
            if (cdcResult.errorRecords > 0) {
                RestContext.response.statusCode = 207;
            }
            return cdcResult;
        } catch (Exception e) {
            throw new GRSYAccRESTException(e.getMessage(), e);
        }
    }

    global class CDCResult {
        public Integer processedRecords;
        public Integer errorRecords;
        public List<Core_Error_Log__c> errors;
    }

    private class GRSYAccRESTException extends Exception {
    }
}