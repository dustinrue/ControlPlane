//
//  UnmuteAction.m
//  MarcoPolo
//
//  Created by David Symonds on 7/06/07.
//

#import "UnmuteAction.h"


@implementation UnmuteAction

- (NSString *)description
{
	return NSLocalizedString(@"Unmuting system audio.", @"");
}

- (BOOL)execute:(NSString **)errorString
{
	NSString *script = @"set volume without output muted";
	NSArray *args = [NSArray arrayWithObjects:@"-e", script, nil];
	NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/osascript" arguments:args];
	[task waitUntilExit];

	// Should never happen
	//if ([task terminationStatus] != 0) {
	//	return NO;
	//}

	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"No parameter for Unmute actions.", @"");
}

@end
