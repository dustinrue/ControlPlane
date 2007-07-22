//
//  ScreenSaverPasswordAction.m
//  MarcoPolo
//
//  Created by David Symonds on 7/06/07.
//

#import <CoreFoundation/CFPreferences.h>
#import "ScreenSaverPasswordAction.h"


@implementation ScreenSaverPasswordAction

- (NSString *)description
{
	if (turnOn)
		return NSLocalizedString(@"Enabling screen saver password.", @"");
	else
		return NSLocalizedString(@"Disabling screen saver password.", @"");
}

- (BOOL)execute:(NSString **)errorString
{
	NSNumber *val = [NSNumber numberWithBool:turnOn];
	CFPreferencesSetValue(CFSTR("askForPassword"), (CFPropertyListRef) val,
			      CFSTR("com.apple.screensaver"),
			      kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
	BOOL success = CFPreferencesSynchronize(CFSTR("com.apple.screensaver"),
				 kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);

	// Notify login process
	if (success) {
		CFMessagePortRef port = CFMessagePortCreateRemote(NULL, CFSTR("com.apple.loginwindow.notify"));
		success = (CFMessagePortSendRequest(port, 500, 0, 0, 0, 0, 0) == kCFMessagePortSuccess);
		CFRelease(port);
	}

	if (!success) {
		*errorString = NSLocalizedString(@"Failed toggling screen saver password!", @"");
		return NO;
	}

	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for ScreenSaverPasswordAction actions is simply either \"on\" "
				 "or \"off\", depending on whether you want your screen saver password "
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
		[NSDictionary dictionaryWithObjectsAndKeys:@"on", @"option",
			NSLocalizedString(@"Enable screen saver password", @""), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:@"off", @"option",
			NSLocalizedString(@"Disable screen saver password", @""), @"description", nil],
		nil];
}

@end
