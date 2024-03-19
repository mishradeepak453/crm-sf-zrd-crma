/**
 * SF-1239:  test class for LWCHandlerUserDisplayComp
 * 
 * @author  miriam.ida.tyroller@accenture.com
 * 
 * @version 2023-10-12  miriam.ida.tyroller       creation
 */

@IsTest
public with sharing class LWCHandlerUserDisplayCompTest {
    
    @TestSetup
    public static void createTestData(){

        // Query one existing Territory to reuse the needed attributes
        List<Territory2> randomExistingTTrs = [SELECT Id, Territory2TypeId, Territory2ModelId FROM Territory2 LIMIT 3];
        Id ttrTypeId = randomExistingTTrs[2].Territory2TypeId;
        Id ttrModelId = randomExistingTTrs[2].Territory2ModelId;
        Id ttrParentId = randomExistingTTrs[2].Id;

        Territory2 terr1 = new Territory2(
            AccountAccessLevel = 'Edit',
            CaseAccessLevel = 'None',
            DeveloperName = 'ZR_Mietstation_5',
            Name = 'ApexTestTerritory 5',
            Core_External_ID__c = 'M999',
            OpportunityAccessLevel = 'Edit',
            Territory2ModelId = ttrModelId,
            Territory2TypeId = ttrTypeId,
            ParentTerritory2Id = ttrParentId
        );
        insert terr1;

        Profile prof = [SELECT Id FROM Profile WHERE Name LIKE '%Administrator%' LIMIT 1]; 
        User us1 = new User(Alias = 'ATU5',
                            Email = 'ApexTestUser5@test.test',
                            EmailEncodingKey = 'UTF-8',
                            LastName = 'Apex Test User 5',
                            LanguageLocaleKey = 'en_US',
                            LocaleSidKey = 'de_DE_EURO',
                            ProfileId = prof.Id,
                            TimeZoneSidKey = 'Europe/Berlin',
                            UserName = 'ApexTestUser5@test.test');
        insert us1;

        UserTerritory2Association usTerrAssoc1 = new UserTerritory2Association();
        usTerrAssoc1.UserId = us1.Id;
        usTerrAssoc1.Territory2Id = terr1.Id;
        usTerrAssoc1.RoleInTerritory2 = 'Assistant';
        insert usTerrAssoc1;

        

    }

    @IsTest
    public static void test_queryUserData() {
        Date todayDate = Date.today();

        // ibau project 
        Project__c project1 = new Project__c();
        project1.Name = 'Test Project 1';
        project1.Project_Address__CountryCode__s = 'DE';
        project1.Project_Address__City__s = 'TestCity';
        project1.Project_Address__PostalCode__s = '12345';
        project1.Project_Address__Street__s = 'Test Street';
        project1.Core_Source_System__c = 'BIS';
        project1.Project_Source__c = '29';
        project1.Project_Construction_Progress__c = '7';
        project1.Exact_Source__c = 'iBau';
        project1.Project_Construction_Start__c = todayDate;
        project1.Total_Volume__c = 2000.00;
        project1.Active__c = true;
        insert project1;

        Project_Territory__c projTerr = new Project_Territory__c();
        projTerr.Project__c = project1.Id;
        projTerr.Territory_ID__c = 'M999';
        projTerr.Territory_Name__c = 'ZR_Mietstation_5';
        projTerr.Business_Area__c = '1';
        insert projTerr; 

        Test.startTest();
            List<LWCHandlerUserDisplayComp.DataTableWrapper> userList = LWCHandlerUserDisplayComp.queryUserData('"Project__c"', project1.Id);
        Test.stopTest();

        System.assertEquals(1,userList.size());
    }

}