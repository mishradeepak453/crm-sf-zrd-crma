/**
 * SF-1205: Test class for FlowActionDuplicateCheck
 *
 * @author  isabella.moos@accenture.com
 *
 * @version 2023-10-25      isabella.moos@accenture.com     creation
 */
@IsTest
private with sharing class DUPDuplicateCheckHelperTest {

    /**
     * Test formatAccountName method
     */
    @isTest
    private static void testFormatAccountName() {
        String accountName1 = ' Test Account 1';
        String accountName2 = '1a Account';
        String accountName3 = 'Übelst toller Account';
        String accountName4 = 'Acc';

        Test.startTest();
            String formattedAccountName1 = DUPDuplicateCheckHelper.formatAccountName(accountName1);
            String formattedAccountName2 = DUPDuplicateCheckHelper.formatAccountName(accountName2);
            String formattedAccountName3 = DUPDuplicateCheckHelper.formatAccountName(accountName3);
            String formattedAccountName4 = DUPDuplicateCheckHelper.formatAccountName(accountName4);
        Test.stopTest();

        System.assertEquals('test,', formattedAccountName1);
        System.assertEquals('1a,', formattedAccountName2);
        System.assertEquals('übelst,', formattedAccountName3);
        System.assertEquals('acc,', formattedAccountName4);
    }

    /**
     * Test addValueToConcatenatedString method
     */
    @isTest
    private static void testAddValueToConcatenatedString() {
        String string1 = '';
        String string2;
        String string3 = 'Test Value 1,';
        String value2BeAdded = 'Test Value 2';

        Test.startTest();
            String formattedString1 = DUPDuplicateCheckHelper.addValueToConcatenatedString(string1, value2BeAdded);
            String formattedString2 = DUPDuplicateCheckHelper.addValueToConcatenatedString(string2, value2BeAdded);
            String formattedString3 = DUPDuplicateCheckHelper.addValueToConcatenatedString(string3, value2BeAdded);
        Test.stopTest();

        System.assertEquals('Test Value 2', formattedString1);
        System.assertEquals('Test Value 2', formattedString2);
        System.assertEquals('Test Value 1,Test Value 2', formattedString3);
    }

    /**
     * Test removeValueInConcatenatedString method
     */
    @isTest
    private static void testRemoveValueInConcatenatedString() {
        String string1 = '';
        String string2;
        String string3 = 'testString1,testString2,testString3,';
        String value2BeRemoved = 'testString2,';

        Test.startTest();
            String formattedString1 = DUPDuplicateCheckHelper.removeValueInConcatenatedString(string1, value2BeRemoved);
            String formattedString2 = DUPDuplicateCheckHelper.removeValueInConcatenatedString(string2, value2BeRemoved);
            String formattedString3 = DUPDuplicateCheckHelper.removeValueInConcatenatedString(string3, value2BeRemoved);
        Test.stopTest();

        System.assertEquals('', formattedString1);
        System.assertEquals('', formattedString2);
        System.assertEquals('testString1,testString3,', formattedString3);
    }

    /**
     * Test replaceValueInConcatenatedString method
     */
    @isTest
    private static void testReplaceValueInConcatenatedString() {
        String string1 = '';
        String string2;
        String string3 = 'testString1,testString2,';
        String value2BeReplaced1 = 'testString2,';
        String value2BeReplaced2 = '';
        String value2BeReplaced3;
        String replacement1 = 'testString3,';
        String replacement2 = '';
        String replacement3;

        Test.startTest();
            String formattedString1 = DUPDuplicateCheckHelper.replaceValueInConcatenatedString(string1, value2BeReplaced1, replacement1);
            String formattedString2 = DUPDuplicateCheckHelper.replaceValueInConcatenatedString(string2, value2BeReplaced1, replacement1);
            String formattedString3 = DUPDuplicateCheckHelper.replaceValueInConcatenatedString(string3, value2BeReplaced1, replacement1);
            String formattedString4 = DUPDuplicateCheckHelper.replaceValueInConcatenatedString(string3, value2BeReplaced2, replacement1);
            String formattedString5 = DUPDuplicateCheckHelper.replaceValueInConcatenatedString(string3, value2BeReplaced3, replacement1);
            String formattedString6 = DUPDuplicateCheckHelper.replaceValueInConcatenatedString(string3, value2BeReplaced1, replacement2);
            String formattedString7 = DUPDuplicateCheckHelper.replaceValueInConcatenatedString(string3, value2BeReplaced1, replacement3);
        Test.stopTest();

        System.assertEquals('', formattedString1);
        System.assertEquals('', formattedString2);
        System.assertEquals('testString1,testString3,', formattedString3);
        System.assertEquals('testString1,testString2,', formattedString4);
        System.assertEquals('testString1,testString2,', formattedString5);
        System.assertEquals('testString1,', formattedString6);
        System.assertEquals('testString1,testString2,', formattedString7);
    }

    /**
     * Test containsCommonValue method
     */
    @isTest
    private static void testContainsCommonValue() {
        List<String> list1 = new List<String>{'testString1','testString2','testString3'};
        List<String> list2 = new List<String>{'testString4','testString3','testString5'};
        List<String> list3 = new List<String>{'testString6'};
        List<String> list4 = new List<String>{''};

        Test.startTest();
            Boolean containsCommonValue1 = DUPDuplicateCheckHelper.containsCommonValue(list1, list2);
            Boolean containsCommonValue2 = DUPDuplicateCheckHelper.containsCommonValue(list1, list3);
            Boolean containsCommonValue3 = DUPDuplicateCheckHelper.containsCommonValue(list1, list4);
        Test.stopTest();

        System.assertEquals(true, containsCommonValue1);
        System.assertEquals(false, containsCommonValue2);
        System.assertEquals(false, containsCommonValue3);
    }

    /**
     * Test getPicklistFieldOptions method
     */
    @isTest
    private static void testGetPicklistFieldOptions() {
        String objectName = 'Project_Account_Relation__c'; 
        String fieldName = 'Account_Role__c';

        Test.startTest();
            List<String> accountRolePicklistValues = DUPDuplicateCheckHelper.getPicklistFieldOptions(objectName, fieldName);
        Test.stopTest();

        System.assertEquals(false, accountRolePicklistValues.isEmpty());
    }

    /**
     * Test formatAddress method
     */
    @isTest
    private static void testFormatAddress() {
        String address1 = 'Teststreet 1';
        String address2 = 'Teststreet 1a';
        String address3 = 'Teststr. 1';
        String address4 = 'Teststr. 1a';
        String address5 = 'Teststr.';
        String address6 = 'Test';
        String address7 = 'St. 1';

        Test.startTest();
            DUPDuplicateCheckHelper.FormattedAddress formattedAddress1 = DUPDuplicateCheckHelper.formatAddress(address1);
            DUPDuplicateCheckHelper.FormattedAddress formattedAddress2 = DUPDuplicateCheckHelper.formatAddress(address2);
            DUPDuplicateCheckHelper.FormattedAddress formattedAddress3 = DUPDuplicateCheckHelper.formatAddress(address3);
            DUPDuplicateCheckHelper.FormattedAddress formattedAddress4 = DUPDuplicateCheckHelper.formatAddress(address4);
            DUPDuplicateCheckHelper.FormattedAddress formattedAddress5 = DUPDuplicateCheckHelper.formatAddress(address5);
            DUPDuplicateCheckHelper.FormattedAddress formattedAddress6 = DUPDuplicateCheckHelper.formatAddress(address6);
            DUPDuplicateCheckHelper.FormattedAddress formattedAddress7 = DUPDuplicateCheckHelper.formatAddress(address7);
        Test.stopTest();

        System.assertEquals('test', formattedAddress1.street);
        System.assertEquals('1', formattedAddress1.streetNumber);
        System.assertEquals('test', formattedAddress2.street);
        System.assertEquals('1', formattedAddress2.streetNumber);
        System.assertEquals('test', formattedAddress3.street);
        System.assertEquals('1', formattedAddress3.streetNumber);
        System.assertEquals('test', formattedAddress4.street);
        System.assertEquals('1', formattedAddress4.streetNumber);
        System.assertEquals('test', formattedAddress5.street);
        System.assertEquals(null, formattedAddress5.streetNumber);
        System.assertEquals('test', formattedAddress6.street);
        System.assertEquals(null, formattedAddress6.streetNumber);
        System.assertEquals('st', formattedAddress7.street);
        System.assertEquals('1', formattedAddress7.streetNumber);
    }
}