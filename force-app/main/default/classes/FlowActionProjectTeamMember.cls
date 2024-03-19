/**
 * SF-1255 Mehrfachanlage von Projektteammitglieder bei PLZ-Änderungen
 * Apex action used in flows Project Territory After Insert Flow and Project After Update Flow to create
 * project team members, avoiding duplicate members and limits
 *
 * @author miriam.ida.tyroller@accenture.com
 * 
 * @version 2023-08-22  miriam.ida.tyroller@accenture.com   creation
 */

public without sharing class FlowActionProjectTeamMember {

    public static final String CLASSNAME = 'FlowActionProjectTeamMember';
    /**
     * InvocableMethod as starting point for each action. Creates project team members based on input project and
     * UserTerritory2Associations, but only if the user isn't already a project team member of the project
     * 
     * @param List<InputVariables> All input variables received from screen flow
     */
    @InvocableMethod(label='Project Team Member Creation' description='Helper method to create project team members ')
    public static void createProjectTeamMembers(List<InputVariables> inputVariables){
        Set<Id> userIds = new Set<Id>();
        List<Core_Error_Log__c> errorLogs = new List<Core_Error_Log__c>();
        List<Project_Team__c> projectTeamMembersToCreate = new List<Project_Team__c>();
        Map<String, Set<Id>> projectTeamMemberListByProjectId = new Map<String, Set<Id>>();

        //only do something if UserTerritory2Association where successfully found
        if(inputVariables.get(0).userTerritoryAssociations?.size() > 0){
            for(UserTerritory2Association usTerrAssoc : inputVariables.get(0).userTerritoryAssociations){
                userIds.add(usTerrAssoc.UserId);
            }

            //query for all Project Team Members with UserIds
            List<Project_Team__c> projectTeamMembers = [SELECT Team_Member__c, Project__c FROM Project_Team__c WHERE Team_Member__c IN: userIds];

            //map Project Team Members by their projects with the related users as a set
            for(Project_Team__c projTeamMember : projectTeamMembers){
                if(projectTeamMemberListByProjectId.keySet().contains(projTeamMember.Project__c)){
                    Set<Id> teamMemberIds = projectTeamMemberListByProjectId.get(projTeamMember.Project__c);
                    teamMemberIds.add(projTeamMember.Team_Member__c);
                    projectTeamMemberListByProjectId.put(projTeamMember.Project__c, teamMemberIds);
                }else{
                    Set<Id> teamMemberIds = new Set<Id>();
                    teamMemberIds.add(projTeamMember.Team_Member__c);
                    projectTeamMemberListByProjectId.put(projTeamMember.Project__c, teamMemberIds);
                }
            }

            //create project team members for input list of UserTerritory2Associations
            for(UserTerritory2Association usTerrAssoc : inputVariables.get(0).userTerritoryAssociations){
                Set<Id> projectTeamMemberIds = projectTeamMemberListByProjectId?.get(inputVariables.get(0).project);
                if(projectTeamMemberIds != null){
                    //only create a project team member if user isn't already linked to project
                    if(!projectTeamMemberIds.contains(usTerrAssoc.UserId)){
                        Project_Team__c projTeamMember = new Project_Team__c();
                        projTeamMember.Project__c = inputVariables.get(0).project;
                        projTeamMember.Team_Member__c = usTerrAssoc.UserId;
                        if(!String.isBlank(usTerrAssoc.RoleInTerritory2)){
                            projTeamMember.Team_Role__c = usTerrAssoc.RoleInTerritory2;
                        }
                        projectTeamMembersToCreate.add(projTeamMember);
                    }
                    else{
                        System.debug('Team Member already exists');
                    }
                }else{
                    Project_Team__c projTeamMember = new Project_Team__c();
                    projTeamMember.Project__c = inputVariables.get(0).project;
                    projTeamMember.Team_Member__c = usTerrAssoc.UserId;
                    if(!String.isBlank(usTerrAssoc.RoleInTerritory2)){
                        projTeamMember.Team_Role__c = usTerrAssoc.RoleInTerritory2;
                    }
                    projectTeamMembersToCreate.add(projTeamMember);
                }
                
            }

            System.debug('########## Project Team Members created: ' + projectTeamMembersToCreate.size());
            System.debug('########## Project Team Members created: ' + projectTeamMembersToCreate);

            if(!projectTeamMembersToCreate.isEmpty()) {
                Database.SaveResult[] ptInsertResult = Database.insert(projectTeamMembersToCreate, false);
                // check results
                Integer i = 0;
                for (Database.SaveResult sr : ptInsertResult) {
                    if (!sr.isSuccess()) {
                        String errorMessage = 'Error while inserting Project_Team__c record with UserId: ' + projectTeamMembersToCreate[i].Team_Member__c + 'for Project: ' + projectTeamMembersToCreate[i].Project__c;
                        String exceptionMessage = sr.getErrors()[0].getStatusCode() + ': ' + sr.getErrors()[0].getMessage();

                        System.debug('########## exceptionMessage: ' + exceptionMessage);
                        errorLogs.add(UTLErrorLog.createErrorLogRecord(CLASSNAME, new HandledException(exceptionMessage), errorMessage, projectTeamMembersToCreate[i].Project__c));
                    }
                    i++;
                }
            }
            
            System.debug('########## errorLogs: ' + errorLogs.size());
            // insert error logs
            UTLErrorLog.insertErrorLogs(errorLogs, CLASSNAME);
        }
    }

    public class InputVariables{
        @InvocableVariable
        public String project; 

        @InvocableVariable
        public List<UserTerritory2Association> userTerritoryAssociations;         
    }
}