/**
 * SF-1058
 * Test class for TTRCreateProjectTerritoriesBatch.
 *
 * @group TTR Territories
 * @date 2023-05-05
 * @author rene.pienkoss@accenture.com
 */
@IsTest
public with sharing class TTRCreateProjectTerritoriesBatchTest {
    
    public static final String postalCode = '07743';

    /**
     * Test Setup
     */
    @TestSetup
	private static void createTestData() {
        // Project
        Project__c project = new Project__c();
        project.Name = 'Test Project';

        project.Project_Address__CountryCode__s = 'DE';
        project.Project_Address__City__s = 'TestCity';
        project.Project_Address__PostalCode__s = postalCode;
        project.Project_Address__Street__s = 'Test Street';
        //project.Postal_Code__c = postalCode;

        insert project;
    }

    /**
     * Test positive creation of Project_Territory__c.
     */
    @isTest 
    private static void testTerritoryCreationSuccess() {
        Test.startTest();

        TTRCreateProjectTerritoriesBatch myBatch = new TTRCreateProjectTerritoriesBatch();
        Database.executeBatch(myBatch, TTRCreateProjectTerritoriesBatch.defaultBatchSize);

        Test.stopTest();

        // validate results
        // query Projects and related Territories
        List<Project__c> projList = [SELECT Id, Postal_Code__c, 
                                            (SELECT Id, Project__c, Territory_ID__c 
                                                FROM Project_Territories__r)
                                        FROM Project__c];

        Assert.areEqual(1, projList.size(), 'Unexpected amount of Products');
        Assert.areEqual(4, projList[0].Project_Territories__r.size(), 'Unexpected amount of Project Territories');
    }
}