//
//  ScreenSaverStartAction.m
//  MarcoPolo
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

- (BOOL)execute:(NSString **)errorString
{
	NSString *script = [NSString stringWithFormat:@"tell application \"ScreenSaverEngine\" to %@",
		(turnOn ? @"activate" : @"quit")];
	NSArray *args = [NSArray arrayWithObjects:@"-e", script, nil];
	NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/osascript" arguments:args];
	[task waitUntilExit];

	if ([task terminationStatus] != 0) {
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
