/**
 * AccountTrigger
 *
 * @author  daniel.gette@zeppelin.com
 *
 * @version 30.12.21 daniel.gette@zeppelin.com creation
 */
trigger AccountTrigger on Account(after insert, after update) {
    new SHRAccountTriggerHandler().run();
}