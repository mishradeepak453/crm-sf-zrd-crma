/**
 * SF-854 Feld "ibau Rückverlinkung"
 *
 * BISBackLinkGeneratorTest
 *
 * @author Daniel Gette
 *
 * @version 14.02.2022 creation
 */

@IsTest
private class BISBackLinkGeneratorTest {

    private static Project__c createTestData(){
        Project__c project = new Project__c();
        project.Name = 'Test Project';

        project.Project_Address__CountryCode__s = 'DE';
        project.Project_Address__City__s = 'TestCity';
        project.Project_Address__PostalCode__s = '55555';
        project.Project_Address__Street__s = 'Test Street';

        return project;
    }

    @IsTest
    static void testLinkGenerationPositive() {
        Project__c project = createTestData();
        project.iBau_ID__c = '12345';
        insert project;

        String url = BISBackLinkGenerator.generateLinkForProject(project.Id);
        System.assert(url.contains(project.iBau_ID__c));
    }

    @IsTest
    static void testLinkGenerationNegativ() {
        Project__c project = createTestData();
        insert project;

        Boolean isExcetion;
        try {
            BISBackLinkGenerator.generateLinkForProject(project.Id);
        } catch (BISBackLinkGenerator.BISBackLinkGeneratorException e) {
            isExcetion = true;
        }
        System.assert(isExcetion);
    }
}