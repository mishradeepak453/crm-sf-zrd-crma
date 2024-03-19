/**
 * Commonly used functionalities for salesforce development.
 *
 * @group UTL Utilities shared over between Orgs
 * @date 27.09.2022
 * @author daniel.gette@zeppelin.com
 */
public with sharing class UTLCommons {
    /**
     * Takes a List of sObjects and maps it by given field. The field ist must be a String field.
     *
     * @param objects the sObject turns into the Map-Value
     * @param field the field of the sObject turns into the Map-Key
     *
     * @return Map<field-value,sObject>
     */
    public static Map<String, SObject> mapByStringField(List<SObject> objects, SObjectField field) {
        if (objects.isEmpty()) {
            return new Map<String, SObject>();
        }

        String sObjectTypeString = String.valueOf(objects[0].getSObjectType());
        Type type = Type.forName('Map<String,' + sObjectTypeString + '>');
        Map<String, SObject> objMap = (Map<String, SObject>) type.newInstance();
        for (SObject obj : objects) {
            String fieldValue = String.valueOf(obj.get(field));
            if (!String.isBlank(fieldValue)) {
                objMap.put(fieldValue, obj);
            }
        }
        return objMap;
    }

    /**
     * Takes a List of sObjects and filter it by given field field. The field ist must be a String field.
     *
     * @param objects the sObject to be filtered
     * @param field the field of the sObject the turns into the Set-Key
     *
     * @return Set<field-value>
     */
    public static Set<String> filterStringFieldValues(List<SObject> objects, SObjectField field) {
        Map<String, SObject> objMap = mapByStringField(objects, field);
        return objMap.keySet();
    }

    /**
     * Takes a ISO8601 Datetime Strings and Parses into Datetime Object
     *
     * @param iso8601_ts ISO8601-Datetime String e.g. 2005-12-04T23:00:00.000Z
     *
     * @return Datetime Object
     */
    public static Datetime convertISO8601(String iso8601_ts) {
        Datetime dt = (Datetime) JSON.deserialize('"' + iso8601_ts + '"', Datetime.class);
        // Bug in JSONParser or DateTime object results in a malformed DateTime,
        // so convert to Long and back to DateTime. Without the conversion,
        // methods that access timeGmt() and its components will actually get
        // local time instead of GMT.
        return Datetime.newInstance(dt.getTime());

        // Once bug is fixed, this return is preferred
        // return dt;
    }

    /**
     * Map Database.Error-Fields into an error message.
     *
     * @param dbError Database.Error
     *
     * @return formatted error message
     */
    public static String parseDbErrorMessage(Database.Error dbError) {
        return String.format(
            'Database Error Message : {0}. StatusCode: {1}. Fields affected this error: {2}',
            new List<String>{
                dbError.getMessage(),
                dbError.getStatusCode().name(),
                String.join(dbError.getFields(), ';')
            }
        );
    }

    /**
     * Validate email String against regex
     *
     * @param email String to validate
     *
     * @return boolean validation result
     */
    public static Boolean validateEmail(String email) {
        String emailRegex = '^[a-zA-Z0-9._|\\\\%#~`=?&/$^*!}{+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,4}$'; // source: http://www.regular-expressions.info/email.html
        Pattern MyPattern = Pattern.compile(emailRegex);
        Matcher MyMatcher = MyPattern.matcher(email);

        return MyMatcher.matches() ? true : false;
    }

    /**
     * Save Database.SaveResults as UTLCommons.DatabaseResults
     *
     * @param saveResults Database results from update DML operation
     *
     * @return List of UTLCommons.DatabaseResults
     */
    public static List<DatabaseResult> mapDatabaseResultList(List<Database.SaveResult> saveResults) {
        List<UTLCommons.DatabaseResult> databaseResults = new List<DatabaseResult>();
        for (Database.SaveResult saveResult : saveResults) {
            databaseResults.add(new DatabaseResult(saveResult));
        }
        return databaseResults;
    }

    /**
     * Save Database.UpsertResults as UTLCommons.DatabaseResults
     *
     * @param upsertResults Database results from upsert DML operation
     *
     * @return List of UTLCommons.DatabaseResults
     */
    public static List<DatabaseResult> mapDatabaseResultList(List<Database.UpsertResult> upsertResults) {
        List<UTLCommons.DatabaseResult> databaseResults = new List<DatabaseResult>();
        for (Database.UpsertResult saveResult : upsertResults) {
            databaseResults.add(new DatabaseResult(saveResult));
        }
        return databaseResults;
    }

    /**
     * Create System.debugs to debug each existing debug limit
     */
    public static void debugLimits() {
        System.debug('Limits.getAggregateQueries()                 = ' + Limits.getAggregateQueries());
        System.debug('Limits.getLimitAggregateQueries()            = ' + Limits.getLimitAggregateQueries());
        System.debug('Limits.getCallouts()                         = ' + Limits.getCallouts());
        System.debug('Limits.getLimitCallouts()                    = ' + Limits.getLimitCallouts());
        System.debug('Limits.getCpuTime()                          = ' + Limits.getCpuTime());
        System.debug('Limits.getLimitCpuTime()                     = ' + Limits.getLimitCpuTime());
        System.debug('Limits.getDMLRows()                          = ' + Limits.getDmlRows());
        System.debug('Limits.getLimitDMLRows()                     = ' + Limits.getLimitDmlRows());
        System.debug('Limits.getDMLStatements()                    = ' + Limits.getDmlStatements());
        System.debug('Limits.getLimitDMLStatements()               = ' + Limits.getLimitDmlStatements());
        System.debug('Limits.getEmailInvocations()                 = ' + Limits.getEmailInvocations());
        System.debug('Limits.getLimitEmailInvocations()            = ' + Limits.getLimitEmailInvocations());
        System.debug('Limits.getFindSimilarCalls()                 = ' + Limits.getFindSimilarCalls());
        System.debug('Limits.getLimitFindSimilarCalls()            = ' + Limits.getLimitFindSimilarCalls());
        System.debug('Limits.getFutureCalls()                      = ' + Limits.getFutureCalls());
        System.debug('Limits.getLimitFutureCalls()                 = ' + Limits.getLimitFutureCalls());
        System.debug('Limits.getHeapSize()                         = ' + Limits.getHeapSize());
        System.debug('Limits.getLimitHeapSize()                    = ' + Limits.getLimitHeapSize());
        System.debug('Limits.getLimitMobilePushApexCalls()         = ' + Limits.getLimitMobilePushApexCalls());
        System.debug('Limits.getQueries()                          = ' + Limits.getQueries());
        System.debug('Limits.getLimitQueries()                     = ' + Limits.getLimitQueries());
        System.debug('Limits.getQueryLocatorRows()                 = ' + Limits.getQueryLocatorRows());
        System.debug('Limits.getLimitQueryLocatorRows()            = ' + Limits.getLimitQueryLocatorRows());
        System.debug('Limits.getQueryRows()                        = ' + Limits.getQueryRows());
        System.debug('Limits.getLimitQueryRows()                   = ' + Limits.getLimitQueryRows());
        System.debug('Limits.getQueueableJobs()                    = ' + Limits.getQueueableJobs());
        System.debug('Limits.getLimitQueueableJobs()               = ' + Limits.getLimitQueueableJobs());
        System.debug('Limits.getRunAs()                            = ' + Limits.getRunAs());
        System.debug('Limits.getLimitRunAs()                       = ' + Limits.getLimitRunAs());
        System.debug('Limits.getSavepointRollbacks()               = ' + Limits.getSavepointRollbacks());
        System.debug('Limits.getLimitSavepointRollbacks()          = ' + Limits.getLimitSavepointRollbacks());
        System.debug('Limits.getSavepoints()                       = ' + Limits.getSavepoints());
        System.debug('Limits.getLimitSavepoints()                  = ' + Limits.getLimitSavepoints());
        System.debug('Limits.getSoslQueries()                      = ' + Limits.getSoslQueries());
        System.debug('Limits.getLimitSoslQueries()                 = ' + Limits.getLimitSoslQueries());
    }

    /**
     * Wrapper class for database results
     */
    public class DatabaseResult {
        private final String ILLIGAL_ARG_EXCETION_MSG = 'Unknown type of DatabaseResult';

        private Database.SaveResult saveResult;
        private Database.UpsertResult upsertResult;

        private Boolean isSaveResult = false;
        private Boolean isUpsertResult = false;

        /**
         * Constructor for update DML operation database result
         */
        public DatabaseResult(Database.SaveResult saveResult) {
            this.saveResult = saveResult;
            this.isSaveResult = true;
        }

        /**
         * Constructor for upsert DML operation database result
         */
        public DatabaseResult(Database.UpsertResult upsertResult) {
            this.upsertResult = upsertResult;
            this.isUpsertResult = true;
        }

        /**
         * Get errors of update / upsert DML operation database result
         *
         * @return list of database errors
         */
        public List<Database.Error> getErrors() {
            if (this.isSaveResult) {
                return saveResult.getErrors();
            } else if (this.isUpsertResult) {
                return upsertResult.getErrors();
            } else {
                throw new IllegalArgumentException(ILLIGAL_ARG_EXCETION_MSG);
            }
        }

        /**
         * Get Id of update / upsert DML operation database result
         *
         * @return Id of database result
         */
        public String getId() {
            if (this.isSaveResult) {
                return saveResult.getId();
            } else if (this.isUpsertResult) {
                return upsertResult.getId();
            } else {
                throw new IllegalArgumentException(ILLIGAL_ARG_EXCETION_MSG);
            }
        }

        /**
         * Return if update / upsert DML operation succeeded
         *
         * @return boolean success result
         */
        public Boolean isSuccess() {
            if (this.isSaveResult) {
                return this.saveResult.isSuccess();
            } else if (this.isUpsertResult) {
                return this.upsertResult.isSuccess();
            } else {
                throw new IllegalArgumentException(ILLIGAL_ARG_EXCETION_MSG);
            }
        }

        /**
         * Return if update / upsert DML operation did not succeed
         *
         * @return boolean error result
         */
        public Boolean isError() {
            return !this.isSuccess();
        }
    }
}