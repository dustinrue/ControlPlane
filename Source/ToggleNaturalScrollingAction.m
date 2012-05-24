//
//  ToggleNaturalScrollingAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 3/25/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "ToggleNaturalScrollingAction.h"
#include <ApplicationServices/ApplicationServices.h>



typedef int CGSConnection;
extern CGSConnection _CGSDefaultConnection(void);
extern void CGSSetSwipeScrollDirection(const CGSConnection cid, BOOL dir);


@implementation ToggleNaturalScrollingAction

- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Enabling Natural Scrolling.", @"Act of turning on or enabling Natural Scrolling is being performed");
	else
		return NSLocalizedString(@"Disabling Natural Scrolling.", @"Act of turning off or disabling Natural Scrolling is being performed");
}

- (BOOL) execute: (NSString **) errorString {
    
    NSMutableDictionary *globalSettings = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:NSGlobalDomain] mutableCopy];
    
    const CGSConnection cid = _CGSDefaultConnection();
    CGSSetSwipeScrollDirection(cid, turnOn);  // YES == natural, NO = unnatural
    
    [globalSettings setValue:[NSNumber numberWithBool:turnOn] forKey:@"com.apple.swipescrolldirection"];
    
    [[NSUserDefaults standardUserDefaults] setPersistentDomain:globalSettings forName:NSGlobalDomain];
    BOOL success = [[NSUserDefaults standardUserDefaults] synchronize];
    
    [globalSettings release];
    
    
	if (!success) {
		if (turnOn)
			*errorString = NSLocalizedString(@"Failed enabling Natural Scrolling.", @"Act of turning on or enabling Natural Scrolling failed");
		else
			*errorString = NSLocalizedString(@"Failed disabling Natural Scrolling.", @"Act of turning off or disabling Natural Scrolling failed");
	}

    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"SwipeScrollDirectionDidChangeNotification" object:nil userInfo:nil];
    
	return success;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for ToggleNaturalScrolling actions is either \"1\" "
                             "or \"0\", depending on whether you want Natural Scrolling "
                             "turned on or off.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Set Natural Scrolling", @"Will be followed by 'on' or 'off'");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Toggle Natural Scrolling", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"System Preferences", @"");
}
@end
