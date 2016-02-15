//
//  ScreenSaverPasswordAction.m
//  ControlPlane
//
//  Created by David Symonds on 7/06/07.
//

#import "ScreenSaverPasswordAction.h"
#import "DSLogger.h"
#import "CPNotifications.h"
#import "CPSystemInfo.h"


@implementation ScreenSaverPasswordAction

- (NSString *)description
{
	if (turnOn)
		return NSLocalizedString(@"Enabling screen saver password.", @"");
	else
		return NSLocalizedString(@"Disabling screen saver password.", @"");
}

- (BOOL)execute:(NSString **)errorString {
    SInt32 version = [CPSystemInfo getOSVersion];
    
    if (version > 1100) {

        BOOL success;
        
        NSNumber *val = [NSNumber numberWithBool:turnOn];
        CFPreferencesSetValue(CFSTR("askForPassword"), (CFPropertyListRef) val,
                      CFSTR("com.apple.screensaver"),
                      kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
        success = CFPreferencesSynchronize(CFSTR("com.apple.screensaver"),
                     kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);

        // Notify login process
        // not sure this does or why it must be called...anyone? (DBR)
        if (success) {
            CFMessagePortRef port = CFMessagePortCreateRemote(NULL, CFSTR("com.apple.loginwindow.notify"));
            if (port) {
                success = (CFMessagePortSendRequest(port, 500, 0, 0, 0, 0, 0) == kCFMessagePortSuccess);
                CFRelease(port);
            }
        }
        
        if (!success) {
            *errorString = NSLocalizedString(@"Failed toggling screen saver password!", @"");
            return NO;
        }
    }
    else {
        NSTask *task = [[NSTask alloc] init];
        if (turnOn)
            [task setLaunchPath:[[NSBundle mainBundle] pathForResource:@"enable_screensaver" ofType:@"sh"]];
        else
            [task setLaunchPath:[[NSBundle mainBundle] pathForResource:@"disable_screensaver" ofType:@"sh"]];
        
        [task setStandardOutput:[NSPipe pipe]];
        [task setStandardInput:[NSPipe pipe]];
        
        task.terminationHandler = ^(NSTask *terminatedTask) {
            int terminationStatus = terminatedTask.terminationStatus;
            if (terminationStatus != 0) {
                DSLog(@"Failed to toggle screensaver password. (script terminated with a non-zero status '%d')",
                      terminationStatus);
                NSString *title = NSLocalizedString(@"Failure", @"Growl message title");
                NSString *errorMsg = NSLocalizedString(@"Failed executing shell script! (see log for details)", @"");
                [CPNotifications postUserNotification:title withMessage:errorMsg];
                return;
            }
        };
        
        [task launch];
    }

	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for ScreenSaverPasswordAction actions is either \"1\" "
				 "or \"0\", depending on whether you want your screen saver password "
				 "enabled or disabled.", @"");
}

+ (NSString *)creationHelpText
{
	// FIXME: is there some useful text we could use?
	return @"";
}

+ (NSArray *)limitedOptions
{
	return [NSArray arrayWithObjects:
		[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"option",
			NSLocalizedString(@"Enable screen saver password", @""), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], @"option",
			NSLocalizedString(@"Disable screen saver password", @""), @"description", nil],
		nil];
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Screen Saver Password", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"System Preferences", @"");
}

+ (BOOL) shouldWaitForScreensaverExit {
    return YES;
}

+ (BOOL) shouldWaitForScreenUnlock {
    return YES;
}

@end
