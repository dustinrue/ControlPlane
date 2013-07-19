//
//  ToggleNotificationCenterAlertsAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 8/13/12.
//
//

#import "ToggleNotificationCenterAlertsAction.h"
#import "CPSystemInfo.h"

@implementation ToggleNotificationCenterAlertsAction

- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Enabling Notification Center Alerts.", @"Act of turning on or enabling Notification Center Alerts is being performed");
	else
		return NSLocalizedString(@"Disabling Notification Center Alerts.", @"Act of turning off or disabling Notification Center Alerts is being performed");
}

- (BOOL) execute: (NSString **) errorString {
    BOOL success = NO;
    
    if (turnOn) {
        
        success = [self enableAlerts:errorString];
        
    }
    else {
        success = [self disableAlerts:errorString];
    }
    
    return success;
}

- (BOOL) enableAlerts:(NSString **)errorString {
    BOOL success = NO;
   
    CFPreferencesSetValue(CFSTR("doNotDisturb"), kCFBooleanFalse, CFSTR("com.apple.notificationcenterui"),
                          kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
    
    CFDateRef date = CFDateCreate(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent());
    
    CFPreferencesSetValue(CFSTR("doNotDisturbDate"), NULL, CFSTR("com.apple.notificationcenterui"),
                          kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
    
    success = CFPreferencesSynchronize(CFSTR("com.apple.notificationcenterui"),
                                       kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
    
    CFRelease(date);
    
    if (success) {
        NSArray *args = [NSArray arrayWithObjects:@"stop", @"com.apple.notificationcenterui.agent", nil];
        
        NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:args];
        
        [task waitUntilExit];
        
        if (task.terminationStatus != 0) {
            *errorString = NSLocalizedString(@"Failed to enable Notification Center Alerts", @"");
            success = NO;
        }
    }
    
    return success;
}

- (BOOL) disableAlerts:(NSString **)errorString {
    BOOL success = NO;

    CFPreferencesSetValue(CFSTR("doNotDisturb"), kCFBooleanTrue, CFSTR("com.apple.notificationcenterui"),
                          kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
    
    CFDateRef date = CFDateCreate(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent());
    
    CFPreferencesSetValue(CFSTR("doNotDisturbDate"), date, CFSTR("com.apple.notificationcenterui"),
                          kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
    
    success = CFPreferencesSynchronize(CFSTR("com.apple.notificationcenterui"),
                                       kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
    
    CFRelease(date);
    
    if (success) {
        NSArray *args = [NSArray arrayWithObjects:@"stop", @"com.apple.notificationcenterui.agent", nil];
        
        NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:args];
        
        [task waitUntilExit];
        
        if (task.terminationStatus != 0) {
            *errorString = NSLocalizedString(@"Failed to disable Notification Center Alerts", @"");
            success = NO;
        }
    }

    
    return success;
}



+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for ToggleNaturalScrolling actions is either \"1\" "
                             "or \"0\", depending on whether you want Notification Center Alerts "
                             "turned on or off.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Set Notification Center Alerts", @"Will be followed by 'on' or 'off'");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Toggle Notification Center Alerts", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"System Preferences", @"");
}

+ (BOOL) isActionApplicableToSystem {

    NSLog(@"%d", (int)[CPSystemInfo getOSVersion]);
    if ([CPSystemInfo getOSVersion] >= MAC_OS_X_VERSION_10_8) {
        return YES;
    }
    else {
        return NO;
    }

}

@end
