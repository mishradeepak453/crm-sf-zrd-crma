/**
 * SF-854 Feld "ibau Rückverlinkung"
 *
 * BISBackLinkGenerator
 *
 * @author Daniel Gette
 *
 * @version 14.02.2022 creation
 */

public with sharing class BISBackLinkGenerator {

    @AuraEnabled(cacheable=true)
    public static String generateLinkForProject(String projectId) {
        Project__c project = [SELECT iBau_ID__c FROM Project__c WHERE Id = :projectId LIMIT 1];

        if (project.iBau_ID__c == null) {
            throw new BISBackLinkGeneratorException('Ibau ID not present on Project');
        }
        return createIbauBacklink(project.iBau_ID__c);
    }

    public static String createIbauBacklink(String ibau_id) {
        BIS_Ibau_Backlink__mdt bisIbauBacklink = BIS_Ibau_Backlink__mdt.getInstance('Ibau_DE');
        String customerId = bisIbauBacklink.Customer_ID__c;
        String md5Password = bisIbauBacklink.Password__c;
        String linkTemplate = bisIbauBacklink.LinkTemplate__c;

        String authToken = createAuthToken(customerId, ibau_id, md5Password);

        String backLink = String.format(
                linkTemplate,
                new List<String>{
                        ibau_id, customerId, authToken
                }
        );
        return backLink;
    }


    /**
     * @param customerId
     * @param ibau_id
     * @param md5Password
     * MD5
     * (
     * MD5( Webservice-Passwort )
     * + MD5( Tag + Monat + Jahr + Kunden-ID + Project-ID )
     * )
     * @return
     */
    private static String createAuthToken(String customerId, String ibau_id, String md5Password) {
        Date currentDate = Date.today();
        String md5innerHash = BISBackLinkGenerator.createMD5String(new List<String>{
                String.valueOf(currentDate.day()),
                String.valueOf(currentDate.month()),
                String.valueOf(currentDate.year()),
                customerId,
                ibau_id
        });
        System.debug(md5innerHash);

        String md5OuterHash = BISBackLinkGenerator.createMD5String(new List<String>{
                md5Password, md5innerHash
        });
        return md5OuterHash;
    }

    public static String createMD5String(String str) {
        Blob targetBlob = Blob.valueOf(str);
        System.debug(targetBlob);
        Blob digest = Crypto.generateDigest('MD5',
                targetBlob
        );
        return EncodingUtil.convertToHex(digest);
    }

    public static String createMD5String(List<String> strings) {
        return createMD5String(String.join(strings, ''));
    }

    @TestVisible
    private class BISBackLinkGeneratorException extends Exception{}
}