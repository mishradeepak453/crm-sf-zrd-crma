/**
* SAMLJITHandler handles SAML JIT request and implements Auth.SamlJitHandler
*
* @version   1.0
* @since     2020-12-16
* @author    kian.parwini@accenture.com
*/
global with sharing class SAMLJITHandler implements Auth.SamlJitHandler {
    public class JitException extends Exception{}
   
    /**
    * createUser is overridden method from Auth.SamlJitHandler interface and will be called during user creation
    * @param attributes to capture JIT parameter
    * @return User records returned after operation
    */
    global User createUser( Id samlSsoProviderId, 
                            Id communityId, 
                            Id portalId,
                            String federationIdentifier, 
                            Map<String, String> attributes, 
                            String assertion) {

        System.debug('SAML JIT HANDLER createUser START');
        System.debug('federationIdentifier: '+federationIdentifier);
        System.debug('assertion: '+assertion);


        User user = new User();
        user=ManageJITUserUtility.handleUserOnboarding(federationIdentifier, new Map<String,Map<String,String>>{'SAML'=>attributes},null, assertion);

        System.debug('SAML JIT HANDLER createUser END');
        return user;
    }

    /**
    * updateUser is overridden method from Auth.SamlJitHandler interface and will be called during user update
    * @param userId to logged in User Id 
    * @param attributes to capture JIT parameter
    * @return User records returned after operation
    */
    global void updateUser( Id userId, 
                            Id samlSsoProviderId, 
                            Id communityId, 
                            Id portalId,
                            String federationIdentifier, 
                            Map<String, String> attributes, 
                            String assertion) {
        
        System.debug('SAML JIT HANDLER updateUser START');
        System.debug('federationIdentifier: '+federationIdentifier);
        System.debug('assertion: '+assertion);

        User user = new User();
        user=ManageJITUserUtility.handleUserOnboarding(federationIdentifier, new Map<String,Map<String,String>>{'SAML'=>attributes},userId, assertion);
        System.debug('SAML JIT HANDLER updateUser END');
    }
    
}