//
//  ScreenSaverPasswordAction.m
//  MarcoPolo
//
//  Created by David Symonds on 7/06/07.
//

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
	// TODO
//	NSString *script = [NSString stringWithFormat:@"set volume %@ output muted",
//				(turnOn ? @"without" : @"with")];
//	NSArray *args = [NSArray arrayWithObjects:@"-e", script, nil];
//	NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/osascript" arguments:args];
//	[task waitUntilExit];

	// Should never happen
	//if ([task terminationStatus] != 0) {
	//	return NO;
	//}

	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for ScreenSaverPasswordAction actions is simply either \"on\" "
				 "or \"off\", depending on whether you want your screen saver password "
				 "enabled or disabled.", @"");
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

+ (NSString *)limitedOptionHelpText
{
	return @"";
}

- (id)initWithOption:(NSString *)option
{
	return [super initWithOption:option];
}

@end
