/**
 * Test class for "FlowActionProjectTeamMember".
 * 
 * @author	miriam.ida.tyroller@accenture.com
 *
 * @version 2023-08-23	miriam.ida.tyroller@accenture.com		creation
 */
@IsTest(SeeAllData=false)
public without sharing class FlowActionProjectTeamMemberTest {

    /**
     * Creates test project, the creation needs to be placed seperately in an TestSetup method to avoid mixed dml operations
     */
    @TestSetup
    public static void createProjects(){
        Project__c proj1 = new Project__c();
        proj1.Name = 'Test Project 1';
        proj1.Project_Address__CountryCode__s = 'DE';
        proj1.Project_Address__City__s = 'TestCity';
        proj1.Project_Address__PostalCode__s = '12345';
        proj1.Project_Address__Street__s = 'Test Street';
        proj1.Core_Source_System__c = 'BIS';
        proj1.Project_Source__c = '29';
        proj1.Project_Construction_Progress__c = '7';
        proj1.Exact_Source__c = 'iBau';
        proj1.Active__c = true;
        insert proj1;

        Project__c proj2 = new Project__c();
        proj2.Name = 'Test Project 2';
        proj2.Project_Address__CountryCode__s = 'DE';
        proj2.Project_Address__City__s = 'TestCity';
        proj2.Project_Address__PostalCode__s = '12345';
        proj2.Project_Address__Street__s = 'Test Street';
        proj2.Core_Source_System__c = 'BIS';
        proj2.Project_Source__c = '29';
        proj2.Project_Construction_Progress__c = '7';
        proj2.Exact_Source__c = 'iBau';
        proj2.Active__c = true;
        insert proj2;
    }

    public static void createTestData(){
        Profile prof = [SELECT Id FROM Profile WHERE Name LIKE '%Administrator%' LIMIT 1]; 
        User us1 = new User(Alias = 'ATU1',Email = 'ApexTestUser@test.test',EmailEncodingKey = 'UTF-8',LastName = 'Apex Test User 1',LanguageLocaleKey = 'en_US',LocaleSidKey = 'de_DE_EURO',ProfileId = prof.Id,TimeZoneSidKey = 'Europe/Berlin',UserName = 'ApexTestUser1@test.test');
        insert us1;

        User us2 = new User(Alias = 'ATU2',Email = 'ApexTestUser@test.test',EmailEncodingKey = 'UTF-8',LastName = 'Apex Test User 2',LanguageLocaleKey = 'en_US',LocaleSidKey = 'de_DE_EURO',ProfileId = prof.Id,TimeZoneSidKey = 'Europe/Berlin',UserName = 'ApexTestUser2@test.test');
        insert us2;

        User us3 = new User(Alias = 'ATU3',Email = 'ApexTestUser@test.test',EmailEncodingKey = 'UTF-8',LastName = 'Apex Test User 3',LanguageLocaleKey = 'en_US',LocaleSidKey = 'de_DE_EURO',ProfileId = prof.Id,TimeZoneSidKey = 'Europe/Berlin',UserName = 'ApexTestUser3@test.test');
        insert us3;

        // Query one existing Territory to reuse the needed attributes
        Territory2 randomExistingTtr = [SELECT Id, Territory2TypeId, Territory2ModelId FROM Territory2 LIMIT 1];

        UserTerritory2Association usTerrAssoc1 = new UserTerritory2Association();
        usTerrAssoc1.UserId = us1.Id;
        usTerrAssoc1.Territory2Id = randomExistingTtr.Id;
        usTerrAssoc1.RoleInTerritory2 = 'Assistant';
        insert usTerrAssoc1;

        UserTerritory2Association usTerrAssoc2 = new UserTerritory2Association();
        usTerrAssoc2.UserId = us2.Id;
        usTerrAssoc2.Territory2Id = randomExistingTtr.Id;
        usTerrAssoc2.RoleInTerritory2 = 'Assistant';
        insert usTerrAssoc2;

        UserTerritory2Association usTerrAssoc3 = new UserTerritory2Association();
        usTerrAssoc3.UserId = us3.Id;
        usTerrAssoc3.Territory2Id = randomExistingTtr.Id;
        usTerrAssoc3.RoleInTerritory2 = 'Assistant';
        insert usTerrAssoc3;
    }



    @IsTest
    static void test_insertProjectTerrExistingTeamMember() {
        createTestData();
        User us1 =[SELECT Id FROM User WHERE Username = 'ApexTestUser1@test.test' LIMIT 1];
        User us2 =[SELECT Id FROM User WHERE Username = 'ApexTestUser2@test.test' LIMIT 1];
        User us3 =[SELECT Id FROM User WHERE Username = 'ApexTestUser3@test.test' LIMIT 1];
        UserTerritory2Association usTerrAssoc = [SELECT Id, Territory2Id FROM UserTerritory2Association WHERE UserId = : us1.Id LIMIT 1];
        Territory2 randomExistingTtr = [SELECT Id, DeveloperName, Core_External_ID__c FROM Territory2 WHERE Id = : usTerrAssoc.Territory2Id LIMIT 1];
        Project__c proj1 = [SELECT Id FROM Project__c WHERE Name = 'Test Project 1'];

        Project_Territory__c projTerr = new Project_Territory__c();
        projTerr.Project__c = proj1.Id;
        projTerr.Territory_ID__c = randomExistingTtr.Core_External_ID__c;
        projTerr.Territory_Name__c = randomExistingTtr.DeveloperName;
        projTerr.Business_Area__c = '1';

        List<Project_Team__c> newTeamMembers = new List<Project_Team__c>();

        Project_Team__c projTeamMember1 = new Project_Team__c();
        projTeamMember1.Project__c = proj1.Id;
        projTeamMember1.Team_Member__c = us1.Id;
        newTeamMembers.add(projTeamMember1);

        Project_Team__c projTeamMember2 = new Project_Team__c();
        projTeamMember2.Project__c = proj1.Id;
        projTeamMember2.Team_Member__c = us3.Id;
        newTeamMembers.add(projTeamMember2);

        List<UserTerritory2Association> usTerrAssocs = [SELECT Id, UserId, RoleInTerritory2 FROM UserTerritory2Association WHERE Territory2Id = : randomExistingTtr.Id];

        List<FlowActionProjectTeamMember.InputVariables> inputVariables = new List<FlowActionProjectTeamMember.InputVariables>();
        FlowActionProjectTeamMember.InputVariables inputVar = new FlowActionProjectTeamMember.InputVariables();
        inputVar.project = proj1.Id;
        inputVar.userTerritoryAssociations = usTerrAssocs;
        inputVariables.add(inputVar);

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
            Test.startTest();
                insert newTeamMembers;
                insert projTerr;
                FlowActionProjectTeamMember.createProjectTeamMembers(inputVariables);
            Test.stopTest();
        }
        
        assertProjectTeamMembers(proj1.Id, us1.Id, 1);
        assertProjectTeamMembers(proj1.Id, us2.Id, 1);
        assertProjectTeamMembers(proj1.Id, us3.Id, 1);
    }

    @IsTest
    static void test_insertProjectTerrNoTeamMember() {
        createTestData();
        User us1 =[SELECT Id FROM User WHERE Username = 'ApexTestUser1@test.test' LIMIT 1];
        User us2 =[SELECT Id FROM User WHERE Username = 'ApexTestUser2@test.test' LIMIT 1];
        User us3 =[SELECT Id FROM User WHERE Username = 'ApexTestUser3@test.test' LIMIT 1];
        UserTerritory2Association usTerrAssoc = [SELECT Id, Territory2Id FROM UserTerritory2Association WHERE UserId = : us1.Id LIMIT 1];
        Territory2 randomExistingTtr = [SELECT Id, DeveloperName, Core_External_ID__c FROM Territory2 WHERE Id = : usTerrAssoc.Territory2Id LIMIT 1];
        Project__c proj2 = [SELECT Id FROM Project__c WHERE Name = 'Test Project 2'];

        Project_Territory__c projTerr = new Project_Territory__c();
        projTerr.Project__c = proj2.Id;
        projTerr.Territory_ID__c = randomExistingTtr.Core_External_ID__c;
        projTerr.Territory_Name__c = randomExistingTtr.DeveloperName;
        projTerr.Business_Area__c = '1';

        List<UserTerritory2Association> usTerrAssocs = [SELECT Id, UserId, RoleInTerritory2 FROM UserTerritory2Association WHERE Territory2Id = : randomExistingTtr.Id];

        List<FlowActionProjectTeamMember.InputVariables> inputVariables = new List<FlowActionProjectTeamMember.InputVariables>();
        FlowActionProjectTeamMember.InputVariables inputVar = new FlowActionProjectTeamMember.InputVariables();
        inputVar.project = proj2.Id;
        inputVar.userTerritoryAssociations = usTerrAssocs;
        inputVariables.add(inputVar);

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
            Test.startTest();
                insert projTerr;
                FlowActionProjectTeamMember.createProjectTeamMembers(inputVariables);
            Test.stopTest();
        }
        
        assertProjectTeamMembers(proj2.Id, us1.Id, 1);
        assertProjectTeamMembers(proj2.Id, us2.Id, 1);
        assertProjectTeamMembers(proj2.Id, us3.Id, 1);
    }

    /**
     *
     * Query projectTeamMembers and assert expected count
     *
     * @param projectId 
     * @param userId
     * @param count
     */
    private static void assertProjectTeamMembers(Id projectId, Id userId, Integer count) {
        List<Project_Team__c> projectTeamMembers = [
            SELECT Id, Project__c, Team_Member__c
            FROM Project_Team__c
            WHERE Project__c = : projectId AND Team_Member__c = : userId
        ];
        System.assertEquals(count, projectTeamMembers.size());
    }
}