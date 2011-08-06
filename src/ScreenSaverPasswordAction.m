//
//  ScreenSaverPasswordAction.m
//  MarcoPolo
//
//  Created by David Symonds on 7/06/07.
//

#import <CoreFoundation/CFPreferences.h>
#import "Common.h"
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
	BOOL success;

	if (!isLeopardOrLater()) {
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
			success = (CFMessagePortSendRequest(port, 500, 0, 0, 0, 0, 0) == kCFMessagePortSuccess);
			CFRelease(port);
		}
	} else {
		NSString *script = [NSString stringWithFormat:
			@"tell application \"System Events\"\n"
			"  tell security preferences\n"
			"    set require password to wake to %@\n"
			"  end tell\n"
			"end tell\n", (turnOn ? @"true" : @"false")];
		success = [self executeAppleScript:script];
	}

	if (!success) {
		*errorString = NSLocalizedString(@"Failed toggling screen saver password!", @"");
		return NO;
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

@end
