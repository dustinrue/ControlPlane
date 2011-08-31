//
//  ScreenSaverStartAction.m
//  ControlPlane
//
//  Created by David Symonds on 4/11/07.
//

#import "ScreenSaverStartAction.h"


@implementation ScreenSaverStartAction

- (NSString *)description
{
	if (turnOn)
		return NSLocalizedString(@"Starting screen saver.", @"");
	else
		return NSLocalizedString(@"Stopping screen saver.", @"");
}

- (BOOL) execute: (NSString **) errorString {
	// Unfortunately, ScreenSaverEngine doesn't support Scripting Bridge
	// Use Cocoa API's to launch and terminate the app instead
	
	NSString *path = @"/System/Library/Frameworks/ScreenSaver.framework/Resources/ScreenSaverEngine.app";
	NSString *identifier = [[NSBundle bundleWithPath: path] bundleIdentifier];
	
	if (turnOn) {
		// launch screensaver
		if ([[NSWorkspace sharedWorkspace] openFile: path])
			return YES;
	} else {
		// terminate
		NSArray *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier: identifier];
		[apps makeObjectsPerformSelector: @selector(terminate)];
		return YES;
	}
	
	if (turnOn)
		*errorString = NSLocalizedString(@"Failed starting screen saver!", @"");
	else
		*errorString = NSLocalizedString(@"Failed stopping screen saver!", @"");
	return NO;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for ScreenSaverStartAction actions is either \"1\" "
				 "or \"0\", depending on whether you want your screen saver to "
				 "start or stop.", @"");
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
			NSLocalizedString(@"Start screen saver", @""), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], @"option",
			NSLocalizedString(@"Stop screen saver", @""), @"description", nil],
		nil];
}

@end
