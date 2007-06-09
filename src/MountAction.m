//
//  MountAction.m
//  MarcoPolo
//
//  Created by David Symonds on 9/06/07.
//

#import "MountAction.h"


@implementation MountAction

- (id)init
{
	if (!(self = [super init]))
		return nil;

	path = [[NSString alloc] init];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super init]))
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
	return [NSString stringWithFormat:NSLocalizedString(@"Mounting '%@'.", @""), path];
}

- (BOOL)execute:(NSString **)errorString
{
	// TODO: properly escape path?
	NSString *script = [NSString stringWithFormat:
		@"tell application \"Finder\"\n"
		"  activate\n"
		"  mount volume \"%@\"\n"
		"end tell\n", path];
	NSArray *args = [NSArray arrayWithObjects:@"-e", script, nil];
	NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/osascript" arguments:args];
	[task waitUntilExit];

	if ([task terminationStatus] != 0) {
		*errorString = NSLocalizedString(@"Couldn't mount that volume!", @"In MountAction");
		return NO;
	}

	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for Mount actions is the volume to mount, such as "
				 "\"smb://server/share\" or \"afp://server/share\".", @"");
}

+ (NSString *)stringHelpText
{
	return NSLocalizedString(@"Mount a volume", @"");
}

- (id)initWithString:(NSString *)string
{
	[self init];
	[path release];
	path = [string copy];
	return self;
}

@end
