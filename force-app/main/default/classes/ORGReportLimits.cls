/**
 * SF-913: Schedulable class to detect and save current usage of org limits for reporting.
 * 
 * @author  rene.pienkoss@accenture.com
 * 
 * @version 2022-05-30  rene.pienkoss@accenture.com     creation
 */
public class ORGReportLimits implements Schedulable {

    public static final String CLASSNAME = 'ORGReportLimits';
    
    /**
     * Run logic to detect and save current limits usage.
     */
    public void detectLimits() {
        try {
            List<System_Limit__c> limitsToInsert = new List<System_Limit__c>();

            limitsToInsert.add(createOrgLimitRecord('DailyApiRequests'));
            /*
            limitsToInsert.add(createOrgLimitRecord('DailyStandardVolumePlatformEvents'));
            limitsToInsert.add(createOrgLimitRecord('HourlyPublishedStandardVolumePlatformEvents'));
            limitsToInsert.add(createOrgLimitRecord('HourlyPublishedPlatformEvents'));
            limitsToInsert.add(createOrgLimitRecord('MonthlyPlatformEventsUsageEntitlement'));
            */

            // get max limit of PLATFORM_EVENTS_DELIVERED
            System_Limit__c pePublishedLimit = createOrgLimitRecord('DailyStandardVolumePlatformEvents');
            pePublishedLimit.Limit_Name__c = 'PLATFORM_EVENTS_DELIVERED';

            // query usage data for the last 24 hours
            List<PlatformEventUsageMetric> peUsageList = [SELECT Name, StartDate, EndDate, Value 
                                                            FROM PlatformEventUsageMetric 
                                                            WHERE Name= 'PLATFORM_EVENTS_DELIVERED' 
                                                                AND EndDate = TODAY 
                                                            ORDER BY EndDate DESC limit 1];
            
            if ( ! peUsageList.isEmpty()) {
                pePublishedLimit.Usage_Value__c = peUsageList[0].Value;
            }
            limitsToInsert.add(pePublishedLimit);

            insert limitsToInsert;
        }
        catch (Exception e) {
            System.debug('########## RP Exception: ' + e.getMessage());
            UTLErrorLog.insertErrorLogs(new List<Core_Error_Log__c>{UTLErrorLog.createErrorLogRecord(CLASSNAME, e, 'Error while reporting Org Limits', null)}, CLASSNAME);
        }
    }

    /**
     * Creates a System_Limit__c record for the given limit name.
     *
     * @return  the created System_Limit__c record
     */
    public static System_Limit__c createOrgLimitRecord(String limitName) {
        System_Limit__c limitRec;

        Map<String, System.OrgLimit> limitsMap = OrgLimits.getMap();
        if (limitsMap.containsKey(limitName)) {
            System.OrgLimit orgLimitRec = limitsMap.get(limitName);

            limitRec = new System_Limit__c();
            limitRec.Limit_Name__c = orgLimitRec.getName();
            limitRec.Usage_Value__c = orgLimitRec.getValue();
            limitRec.Maximum_Limit__c = orgLimitRec.getLimit();
        }

        return limitRec;
    }

    /**
     * The execute method is used to instantiate the class to be scheduled.
     */
    public void execute(SchedulableContext sc) {
        ORGReportLimits orgLimitsJob = new ORGReportLimits();
        orgLimitsJob.detectLimits();
    }
}