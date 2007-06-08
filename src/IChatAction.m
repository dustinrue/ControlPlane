//
//  IChatAction.m
//  MarcoPolo
//
//  Created by David Symonds on 8/06/07.
//

#import "IChatAction.h"


@implementation IChatAction

- (id)init
{
	if (!(self = [super init]))
		return nil;

	status = @"";

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super init]))
		return nil;

	status = [dict valueForKey:@"parameter"];

	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];

	[dict setObject:status forKey:@"parameter"];

	return dict;
}

- (NSString *)description
{
	return [NSString stringWithFormat:NSLocalizedString(@"Setting iChat status to '%@'.", @""), status];
}

- (BOOL)execute:(NSString **)errorString
{
	// TODO: properly escape status message!
	NSString *script = [NSString stringWithFormat:
		@"tell application \"iChat\"\n"
		"  set status message to \"%@\"\n"
		"end tell\n", status];
	NSLog(@"APPLE SCRIPT:\n%@", script);
	NSArray *args = [NSArray arrayWithObjects:@"-e", script, nil];
	NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/osascript" arguments:args];
	[task waitUntilExit];

	if ([task terminationStatus] != 0) {
		*errorString = NSLocalizedString(@"Couldn't set iChat status!", @"In IChatAction");
		return NO;
	}

	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for IChat actions is the status message to set.", @"");
}

+ (NSString *)stringHelpText
{
	return NSLocalizedString(@"Set iChat status message to", @"");
}

- (id)initWithString:(NSString *)string
{
	[self init];
	status = string;
	return self;
}

@end
