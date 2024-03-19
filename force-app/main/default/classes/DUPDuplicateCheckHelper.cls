/**
 * SF-1205: Helper class to provide reusable methods for duplicate check
 *
 * @author  isabella.moos@accenture.com
 *
 * @version 2023-10-19      isabella.moos@accenture.com     creation
 */
public with sharing class DUPDuplicateCheckHelper {
    /**
     * Helper method to format account names:
     * remove any special character and whitespaces before first and after last character
     * keep only first word before first whitespace
     * format all in Lower Case
     * 
     * @param accountName account name to be formatted
     * 
     * @return String with formatted account name separated by comma
     */
    public static String formatAccountName(String accountName) {
        String formattedAccountName;
        
        formattedAccountName = accountName.replaceAll('[\\-‚\'!"#$%&\\()*+,./:;<=>?@^_`{|}~\\[\\]]', '').trim().subStringBefore(' ').toLowercase();
        formattedAccountName += ',';
        
        return formattedAccountName;
    }

    /**
     * Helper method to add new value to comma separated string
     * 
     * @param concatenatedString string with comma separated values
     * @param stringToBeAdded String that should be replaced
     * 
     * @return String of concatenated values including replaced value
     */
    public static String addValueToConcatenatedString(String concatenatedString, String stringToBeAdded) {
        if(concatenatedString != null) {
            concatenatedString += stringToBeAdded;
        } else {
            concatenatedString = stringToBeAdded;
        }

        return concatenatedString;
    }

    /**
     * Helper method to remove one value of comma separated string
     * 
     * @param concatenatedString string with comma separated values
     * @param stringToBeRemoved string that should be removed
     * 
     * @return String of concatenated values including replaced value
     */
    public static String removeValueInConcatenatedString(String concatenatedString, String stringToBeRemoved) {
        String formattedString = '';
        List<String> list1 = DUPDuplicateCheckHelper.formatConcatenatedStringToList(concatenatedString, ',');

        if(! list1.isEmpty() && stringToBeRemoved != null) {
            stringToBeRemoved = stringToBeRemoved.subStringBefore(',');
            for (Integer i = 0; i < list1.size(); i++) {
                if(list1[i] == stringToBeRemoved) {
                    list1.remove(i);
                    break;
                }
            }
        }

        for(String value : list1) {
            if(value != null && formattedString != '') {
                formattedString += value;
            } else if (value != null && formattedString == '') {
                formattedString = value;
            }
            if(value != '') {
                formattedString += ',';
            }
        }

        return formattedString;
    }

    /**
     * Helper method to exchange one value of comma separated string
     * 
     * @param concatenatedString string with comma separated values
     * @param replacement string that should replace single value in concatenatedString
     * @param stringToBeReplaced string that should be replaced
     * 
     * @return String of concatenated values including replaced value
     */
    public static String replaceValueInConcatenatedString(String concatenatedString, String stringToBeReplaced, String replacement) {
        String formattedString = '';
        if(stringToBeReplaced != null) {
            stringToBeReplaced = stringToBeReplaced.subStringBefore(',');
        }
        if(replacement != null) {
            replacement = replacement.subStringBefore(',');
        }

        List<String> list1 = DUPDuplicateCheckHelper.formatConcatenatedStringToList(concatenatedString, ',');

        if(! list1.isEmpty() && replacement != null && stringToBeReplaced != null) {
            for (Integer i = 0; i < list1.size(); i++) {
                if(list1[i] == stringToBeReplaced) {
                    list1.set(i, replacement);
                    break;
                }
            }
        }

        for(String value : list1) {
            if(value != null && formattedString != '') {
                formattedString += value;
            } else if (value != null && formattedString == '') {
                formattedString = value;
            }
            if(value != '') {
                formattedString += ',';
            }
        }

        return formattedString;
    }

    /**
     * Helper method to get picklist field options (only api names), without Building Owner
     * 
     * @param concatenatedString string with comma separated values
     * @param stringToBeRemoved string that should be removed
     * 
     * @return String of concatenated values including replaced value
     */
    public static List<String> getPicklistFieldOptions(String objectName, String fieldName) {  
        List<String> picklistOptionsAPINames = new List<String>();
        SObject instance = (SObject) Type.forName('Schema.' + objectName).newInstance();
        Schema.DescribeSObjectResult objDescribeSobject = instance.getSObjectType().getDescribe();
        Map<String,Schema.SObjectField> fields = objDescribeSobject.fields.getMap() ;
        Schema.DescribeFieldResult fieldResult = fields.get(fieldName).getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        
        for( Schema.PicklistEntry pickListVal : ple){
            if(pickListVal.getValue() != '3') {
                picklistOptionsAPINames.add(pickListVal.getValue());
            }
            
        }

        return picklistOptionsAPINames;
    }

    /**
     * Helper method to split concatenated String to List<String>
     * 
     * @param concatenatedString string with comma separated values
     * @param stringToBeRemoved string that should be removed
     * 
     * @return String of concatenated values including replaced value
     */
    public static List<String> formatConcatenatedStringToList(String concatenatedString, String separator) {
        List<String> list1 = new List<String>();

        if(concatenatedString != null && concatenatedString.contains(separator)) {
            list1 = concatenatedString.split(separator);
        } else if(concatenatedString != null && ! concatenatedString.contains(separator)) {
            list1.add(concatenatedString);
        }

        return list1;
    }

    /**
     * Helper method to identify if list 1 and list 2 contain at least one similar value
     * 
     * @param list1 list of String values
     * @param list2 list of String values
     * 
     * @return True if contains common values
     */
    public static Boolean containsCommonValue(List<String> list1, List<String> list2) {
        Boolean containsCommonValue = false;

        if(! list1.isEmpty() && ! list2.isEmpty()) {
            for (String value : list1) {
                if(list2.contains(value) && value != null) {
                    containsCommonValue = true;
                    break;
                }
            }
        }

        return containsCommonValue;
    }

    /**
     * Helper method to format address:
     * separate street from street number
     * street number: remove any non-numeric and special characters and whitespace, keep only first 4 character
     * street: remove any special characters and whitespace, keep only first 4 character
     * format all in Lower Case
     * 
     * @param addressStreet unformatted string of concatenated street and street number
     * 
     * @return FormattedAddress with formatted street and street number
     */
    public static FormattedAddress formatAddress(String addressStreet) {
        FormattedAddress formattedAddress = new FormattedAddress();

        Pattern pattern = Pattern.compile('^(\\b\\D+\\b)?\\s*(\\b.*?\\d.*?\\b)\\s*(\\b\\D+\\b)?$');
        Matcher matcher = pattern.matcher(addressStreet);

        if (matcher.find()) {         
            for (Integer i = 1; i <= matcher.groupCount(); i++) {
                if(matcher.group(i) != null) {
                    String match = matcher.group(i);
                    String firstChar = match.substring(0,1);

                    //street number: remove any non-numeric and special characters and whitespace
                    if(firstChar.isNumeric()) { 
                        formattedAddress.streetNumber = (matcher.group(i)).replaceAll('[^\\w\\s]|[^0-9.]', '').deleteWhitespace().toLowercase();
                    //street: remove any special characters and whitespace, keep only first 4 character
                    } else {
                        formattedAddress.street = (matcher.group(i)).replaceAll('[^\\w\\s]', '').deleteWhitespace().toLowercase();
                        if(formattedAddress.street.length() > 4) {
                            formattedAddress.street = formattedAddress.street.substring(0,4);
                        }
                    }
                }
            }
        } else if (addressStreet != null) {
            formattedAddress.street = addressStreet.replaceAll('[^\\w\\s]', '').deleteWhitespace().toLowercase();
            if(formattedAddress.street.length() > 4) {
                formattedAddress.street = formattedAddress.street.substring(0,4);
            }
        }
        
        return formattedAddress;
    }

    /**
     * Wrapper for formatted address
     */
    public class FormattedAddress{
        public String street;
        public String streetNumber;
    }
}