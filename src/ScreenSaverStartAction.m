//
//  ScreenSaverStartAction.m
//  ControlPlane
//
//  Created by David Symonds on 4/11/07.
//

#import "ScreenSaverStartAction.h"
#import <ScriptingBridge/SBApplication.h>
#import "System Events.h"


@implementation ScreenSaverStartAction

- (NSString *)description
{
	if (turnOn)
		return NSLocalizedString(@"Starting screen saver.", @"");
	else
		return NSLocalizedString(@"Stopping screen saver.", @"");
}

- (BOOL) execute: (NSString **) errorString {
	@try {
		SystemEventsApplication *SEvents = [SBApplication applicationWithBundleIdentifier: @"com.apple.systemevents"];
		
		// start/stop
		if (turnOn)
			[SEvents.currentScreenSaver start];
		else
			[SEvents.currentScreenSaver stop];
		
	} @catch (NSException *e) {
		if (turnOn)
			*errorString = NSLocalizedString(@"Failed starting screen saver!", @"");
		else
			*errorString = NSLocalizedString(@"Failed stopping screen saver!", @"");
		return NO;
	}
	
	return YES;
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
