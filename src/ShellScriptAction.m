//
//  ShellScriptAction.m
//  ControlPlane
//
//  Created by David Symonds on 23/04/07.
//

#import "ShellScriptAction.h"


@implementation ShellScriptAction

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
	return [NSString stringWithFormat:NSLocalizedString(@"Running shell script '%@'.", @""), path];
}

- (BOOL)execute:(NSString **)errorString
{
	// Split on "|", add "--" to the start so that the shell won't try to parse arguments
	NSMutableArray *args = [[[path componentsSeparatedByString:@"|"] mutableCopy] autorelease];
	[args insertObject:@"--" atIndex:0];

	NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:args];
	[task waitUntilExit];

	if ([task terminationStatus] != 0) {
		*errorString = NSLocalizedString(@"Failed executing shell script!", @"");
		return NO;
	}

	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for ShellScript actions is the full path of the "
				 "shell script, which will be executed with /bin/sh.", @"");
}

- (id)initWithFile:(NSString *)file
{
	[self init];
	[path release];
	path = [file copy];
	return self;
}

@end
