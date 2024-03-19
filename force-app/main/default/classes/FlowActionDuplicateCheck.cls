/**
 * SF-1205 
 * Apex action used in flow
 *
 * @author isabella.moos@accenture.com
 * 
 * @version 2023-09-26  isabella.moos@accenture.comm   creation
 */
public without sharing class FlowActionDuplicateCheck {
    private static final String CLASSNAME = 'FlowActionDuplicateCheck';
    private static String PROJECT_ACCOUNT_RELATION_SOBJECT_API_NAME = 'Project_Account_Relation__c';
    private static String ACCOUNT_ROLE_FIELD_API_NAME = 'Account_Role__c';

    /**
     * Invocable Method as starting point for the duplicate check. 
     * 
     * @param List<InputVariables> All input variables received from screen flow
     * 
     * @return List<OutputVariables> as output for flow
     */
    @InvocableMethod(label='Duplicate Check' description='Invocable method for duplicate check to process different flow actions')
    public static List<OutputVariables> initDuplicateCheck(List<InputVariables> inputVariables){
        List<Core_Error_Log__c> errorLogs = new List<Core_Error_Log__c>();
        List<OutputVariables> outputVariablesList = new List<OutputVariables>();

        try {
            for(Integer i = 0; i < inputVariables.size(); i++) {

                OutputVariables outputVariable = new OutputVariables();

                if(inputVariables[i].cleanseProjectFields == true) {
                    outputVariable.flowProject = cleanseHelperFields(inputVariables[i]);
                } 
                if(inputVariables[i].executeDuplicateCheck == true) {
                    outputVariable.potentialDuplicateProjectList = executeDuplicateCheck(inputVariables[i].project);
                }
    
                if(outputVariable.potentialDuplicateProjectList != null && ! outputVariable.potentialDuplicateProjectList.isEmpty()) {
                    outputVariable.potentialDuplicateProjectAvailable = true;
                } else {
                    outputVariable.potentialDuplicateProjectAvailable = false;
                }
        
                outputVariablesList.add(outputVariable);
            }

        } catch (Exception ex) {
            Core_Error_Log__c errorLog = UTLErrorLog.createErrorLogRecord(CLASSNAME, 
                                                                            ex, 
                                                                            'Error while duplicate check: ' + ex.getMessage(), 
                                                                            null, 
                                                                            null, 
                                                                            true);
            errorLogs.add(errorLog);
            UTLErrorLog.insertErrorLogs(errorLogs, CLASSNAME);
        }

        return outputVariablesList;
    }

    /**
     * Helper method to cleanse helper field values and store them in project variable
     * 
     * @param flowInput flow input variable containing info about project and related records
     * 
     * @return Project__c record with cleansed helper fields
     */
    private static Project__c cleanseHelperFields(InputVariables flowInput) {
        List<Project_Account_Relation__c> projectAccountRelations = flowInput.projectAccountRelations;
        List<Project_Account_Lead_Relation__c> projectAccountLeadRelations = flowInput.projectAccountLeadRelations;
        Map<Id, Account> involvedAccountsList = new Map<Id, Account>();
        Map<Id, Account_Lead__c> accountLeadsList = new Map<Id, Account_Lead__c>();
        if(flowInput.relatedAccountsList != null && !flowInput.relatedAccountsList.isEmpty()) {
            involvedAccountsList.putAll(flowInput.relatedAccountsList);
        }
        if(flowInput.relatedAccountLeadsList != null && !flowInput.relatedAccountLeadsList.isEmpty()) {
            accountLeadsList.putAll(flowInput.relatedAccountLeadsList);
        }
        Project__c cleansedProject = flowInput.project;
        Id flowProjectId = cleansedProject.Id;
        String formattedBuildingOwnerName;
        String formattedInvolvedAccountNames;

        //format project address
        if(cleansedProject.Project_Address__Street__s != null) {
            DUPDuplicateCheckHelper.FormattedAddress formattedAddress = DUPDuplicateCheckHelper.formatAddress(cleansedProject.Project_Address__Street__s);
            cleansedProject.Street_cleaned__c =  formattedAddress.street;
            cleansedProject.House_Number_cleaned__c =  formattedAddress.streetNumber;
        }

        // prepare involved account list if project record was created within flow and not inserted yet
        if(flowProjectId == null && projectAccountRelations != null) {
            for(Project_Account_Relation__c par : projectAccountRelations) {
                involvedAccountsList.put(par.Account__c, new Account());
            }

            Set<Id> accIds = involvedAccountsList.keySet();
            if(! accIds.isEmpty()) {
                for(Account acc : [SELECT 
                                        Name,
                                        Id     
                                    FROM Account 
                                    WHERE Id IN :accIds]) {
                    involvedAccountsList.put(acc.Id, acc);
                }
            }
        }
        
        // prepare project helper fields with involved Account Leads
        if( projectAccountLeadRelations != null && 
        !projectAccountLeadRelations.isEmpty()) {
            for(Project_Account_Lead_Relation__c accountLead : projectAccountLeadRelations) {
                if(accountLead.Account_Role__c == '3' && (cleansedProject.Building_Owner_cleaned__c == null || cleansedProject.Building_Owner_cleaned__c == '')) {
                    cleansedProject.Building_Owner_cleaned__c = DUPDuplicateCheckHelper.formatAccountName(accountLeadsList.get(accountLead.Account_Lead__c).Name);
                } else {
                    if(cleansedProject.Involved_Accounts_cleaned__c != null) {
                        cleansedProject.Involved_Accounts_cleaned__c += DUPDuplicateCheckHelper.formatAccountName(accountLeadsList.get(accountLead.Account_Lead__c).Name);
                    } else {
                        cleansedProject.Involved_Accounts_cleaned__c = DUPDuplicateCheckHelper.formatAccountName(accountLeadsList.get(accountLead.Account_Lead__c).Name);
                    }
                }
            }
        }

        // prepare project helper fields with involved Accounts
        if( involvedAccountsList.values() != null && 
        !involvedAccountsList.values().isEmpty() && 
        projectAccountRelations != null && 
        !projectAccountRelations.isEmpty()) {
            List<String> accountRoleOptions = DUPDuplicateCheckHelper.getPicklistFieldOptions(PROJECT_ACCOUNT_RELATION_SOBJECT_API_NAME, ACCOUNT_ROLE_FIELD_API_NAME);

            for(Project_Account_Relation__c involvedAccount : projectAccountRelations) {
                if(involvedAccount.Account_Role__c != null && 
                involvedAccount.Account_Role__c.contains('3')) {
                    cleansedProject.Building_Owner_cleaned__c = DUPDuplicateCheckHelper.formatAccountName(involvedAccountsList.get(involvedAccount.Account__c).Name);
                    cleansedProject.Building_Owner__c = involvedAccountsList.get(involvedAccount.Account__c).Name;
                } 

                List<String> accountRoles = DUPDuplicateCheckHelper.formatConcatenatedStringToList(involvedAccount.Account_Role__c, ';');
                if(DUPDuplicateCheckHelper.containsCommonValue(accountRoleOptions, accountRoles) || 
                involvedAccount.Account_Role__c == null) {
                    if(cleansedProject.Involved_Accounts_cleaned__c != null) {
                        cleansedProject.Involved_Accounts_cleaned__c += DUPDuplicateCheckHelper.formatAccountName(involvedAccountsList.get(involvedAccount.Account__c).Name);
                    } else {
                        cleansedProject.Involved_Accounts_cleaned__c = DUPDuplicateCheckHelper.formatAccountName(involvedAccountsList.get(involvedAccount.Account__c).Name);
                    }
                }
            }
        }
        
        return cleansedProject; 
    }

    /**
     * Helper method to execute duplicate check based on cleansed address fields and account name
     *
     * @param flowProject manually created project within screen flow
     * 
     * @return List<Project__c> potential duplicate project records to be presented to the user in the screen flow
     */
    private static List<Project__c> executeDuplicateCheck(Project__c flowProject) {
        List<Project__c> finalPotentialDuplicateProjectList = new List<Project__c>();
        Decimal flowProjectLong = flowProject.Project_Address__Longitude__s;
        Decimal flowProjectLat = flowProject.Project_Address__Latitude__s;
        String flowProjectPostalCode = flowProject.Project_Address__PostalCode__s;

        // query potential duplicate projects by same geolocation or same postal code
        List<Project__c> potentialDuplicateProjectList = getProjectRecords(flowProjectLong, flowProjectLat, flowProjectPostalCode);

        Map<Id, Project__c> potentialDuplicateProjectMap = new Map<Id, Project__c>(potentialDuplicateProjectList);
        Set<Id> potentialDuplicateProjectIds = potentialDuplicateProjectMap.keySet();
        if(! potentialDuplicateProjectList.isEmpty()) {
            for(Project__c project : potentialDuplicateProjectList) {

                if(project.Project_Address__Longitude__s != null && 
                flowProject.Project_Address__Latitude__s != null &&
                project.Project_Address__Longitude__s == flowProject.Project_Address__Longitude__s &&  
                project.Project_Address__Latitude__s  == flowProject.Project_Address__Latitude__s ) {                   // 1. Check Geolocation
                    System.debug('#### potential duplicate due to geolocation check');
                    finalPotentialDuplicateProjectList.add(project);
                    
                } else if(project.Project_Address__PostalCode__s == flowProject.Project_Address__PostalCode__s) {       // 2. Check PLZ
                    
                    if((project.Street_cleaned__c == flowProject.Street_cleaned__c &&
                    project.Street_cleaned__c != null &&
                    flowProject.Street_cleaned__c != null) ||
                    (project.Project_Address__c != null && 
                    flowProject.Project_Address__c != null &&
                    Location.getDistance(project.Project_Address__c, flowProject.Project_Address__c, 'km') < 2)) {       // 3. Check Street and location radius

                        if(project.House_Number_cleaned__c == flowProject.House_Number_cleaned__c &&                     // 4. Check Street Number
                        project.House_Number_cleaned__c != null && 
                        flowProject.House_Number_cleaned__c != null) {                    
                            System.debug('#### potential duplicate due to street and street number check');
                            finalPotentialDuplicateProjectList.add(project);
                        
                        } else if((project.House_Number_cleaned__c != flowProject.House_Number_cleaned__c ||             // 5. Check Involved Accounts & Building Owner Names
                        project.House_Number_cleaned__c == null || flowProject.House_Number_cleaned__c == null) &&            
                        ((project.Building_Owner_cleaned__c != null &&
                            flowProject.Building_Owner_cleaned__c != null &&
                            project.Building_Owner_cleaned__c == flowProject.Building_Owner_cleaned__c) ||
                        DUPDuplicateCheckHelper.containsCommonValue(
                            DUPDuplicateCheckHelper.formatConcatenatedStringToList(project.Involved_Accounts_cleaned__c, ','), 
                            DUPDuplicateCheckHelper.formatConcatenatedStringToList(flowProject.Involved_Accounts_cleaned__c, ',')
                        ))) {             
                            System.debug('#### potential duplicate due to involved account check');
                            finalPotentialDuplicateProjectList.add(project);
                        }
                    
                    } else if(flowProject.Street_cleaned__c == null && 
                    flowProject.Project_Address__Longitude__s == null && 
                    flowProject.Project_Address__Latitude__s == null) {
                        // future logic
                    }
                } 
            }
        }
        
        return finalPotentialDuplicateProjectList;
    }

    /**
     * Helper method to query duplicate project records
     * 
     * @param string1 string with comma separated values
     * @param string2 string with comma separated values
     * 
     * @return Boolean true if two lists contain at least one common value
     */
    private static List<Project__c> getProjectRecords(Decimal flowProjectLong, Decimal flowProjectLat, String flowProjectPostalCode) {
        return [SELECT 
                    Id, 
                    Name, 
                    Project_Construction_Progress__c,
                    Street__c,
                    Project_Address__Street__s,
                    Postal_Code__c,
                    City__c,
                    Total_Volume__c,
                    Project_Construction_Start__c,
                    Potential__c,
                    Core_Source_System__c, 
                    Project_Address__c, 
                    Project_Address__Longitude__s, 
                    Project_Address__Latitude__s, 
                    Project_Address__PostalCode__s, 
                    Street_cleaned__c, 
                    House_Number_cleaned__c,
                    Involved_Accounts_cleaned__c,
                    Building_Owner_cleaned__c,
                    Building_Owner__c,
                    Owner.Name,
                    OwnerId,
                    CreatedDate//,
                    /*(SELECT 
                        Id, 
                        Account__r.Name
                    FROM Project_Account_Relations__r 
                    WHERE Account_Role__c = '3' LIMIT 1)*/
                FROM Project__c 
                WHERE Core_Source_System__c = 'BIS' 
                AND (((Project_Address__Longitude__s = :flowProjectLong 
                            AND Project_Address__Longitude__s != null) 
                        AND (Project_Address__Latitude__s = :flowProjectLat 
                            AND Project_Address__Latitude__s != null)) 
                    OR Project_Address__PostalCode__s = :flowProjectPostalCode)
        ];
    }

    /**
     * Input variables of screen flow
     */
    public class InputVariables{
        @InvocableVariable (Label='Manual Project' Description='Manual project created by screen flow' Required=true)
        public Project__c project; 

        @InvocableVariable (Label='Project Account Relations' Description='Project Account Relations created by screen flow' Required=false)
        public List<Project_Account_Relation__c> projectAccountRelations; 

        @InvocableVariable (Label='Involved Accounts' Description='Involved Accounts by screen flow' Required=false)
        public List<Account> relatedAccountsList; 

        @InvocableVariable (Label='Project Account Lead Relations' Description='Project Account Lead Relations created by screen flow' Required=false)
        public List<Project_Account_Lead_Relation__c> projectAccountLeadRelations; 

        @InvocableVariable (Label='Involved Account Leads' Description='Involved Account Leads by screen flow' Required=false)
        public List<Account_Lead__c> relatedAccountLeadsList; 

        @InvocableVariable (Label='Cleanse Project Fields' Description='If true, fields of project created in flow are getting cleansed' Required=true)
        public Boolean cleanseProjectFields;

        @InvocableVariable (Label='Execute Duplicate Check' Description='If true, duplicate check is performed and potential duplicates returned' Required=true)
        public Boolean executeDuplicateCheck;
    }

    /**
     * Output variables of screen flow
     */
    public class OutputVariables{
        @InvocableVariable (Label='Manual Project' Description='Manual project updated by Apex Action' Required=false)
        public Project__c flowProject; 

        @InvocableVariable (Label='Potential Duplicates' Description='List of potential duplicate projects' Required=false)
        public List<Project__c> potentialDuplicateProjectList; 

        @InvocableVariable (Label='Potential Duplicates Available' Description='True if potential duplicates could be found' Required=false)
        public Boolean potentialDuplicateProjectAvailable; 
    }
}