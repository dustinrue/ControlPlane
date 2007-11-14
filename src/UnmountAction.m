//
//  UnmountAction.m
//  MarcoPolo
//
//  Created by Mark Wallis on 14/11/07.
//

#import "UnmountAction.h"


@implementation UnmountAction

- (id)init
{
	if (!(self = [super init]))
		return nil;

	path = [[NSString alloc] init];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super initWithDictionary:dict]))
		return nil;

	path = [[dict valueForKey:@"parameter"] copy];

	return self;
}

- (void)dealloc
{
	[path release];

	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];

	[dict setObject:[[path copy] autorelease] forKey:@"parameter"];

	return dict;
}

- (NSString *)description
{
	return [NSString stringWithFormat:NSLocalizedString(@"Unmounting '%@'.", @""), path];
}

- (BOOL)execute:(NSString **)errorString
{
	// TODO: properly escape path?
	NSString *script = [NSString stringWithFormat:
		@"tell application \"Finder\"\n"
		"  activate\n"
		"  eject \"%@\"\n"
		"end tell\n", path];
	NSArray *args = [NSArray arrayWithObjects:@"-e", script, nil];
	NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/osascript" arguments:args];
	[task waitUntilExit];

	if ([task terminationStatus] != 0) {
		*errorString = NSLocalizedString(@"Couldn't unmount that volume!", @"In UnmountAction");
		return NO;
	}

	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for Unmount actions is the volume name to unmount. "
				 "You can find the volume name in the /Volumes/ folder after a successful mount.", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Unmount a volume with mount location", @"");
}

@end
