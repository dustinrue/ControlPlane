//
//  QuitApplicationAction.m
//  ControlPlane
//
//  Created by David Symonds on 15/10/07.
//

#import "QuitApplicationAction.h"
#import "DSLogger.h"


@implementation QuitApplicationAction

- (id)init
{
	if (!(self = [super init]))
		return nil;

	application = [[NSString alloc] init];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super initWithDictionary:dict]))
		return nil;

	application = [[dict valueForKey:@"parameter"] copy];

	return self;
}

- (void)dealloc
{
	[application release];

	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];

	[dict setObject:[[application copy] autorelease] forKey:@"parameter"];

	return dict;
}

- (NSString *)description
{
	return [NSString stringWithFormat:NSLocalizedString(@"Quitting application '%@'.", @""), application];
}

- (BOOL)execute:(NSString **)errorString
{
	// get bundle identifier
	NSString *path = [[NSWorkspace sharedWorkspace] fullPathForApplication: application];
	NSString *identifier = [[NSBundle bundleWithPath: path] bundleIdentifier];
	
	// terminate
	DSLog(@"Terminating all instances of application '%@'", identifier);
	NSArray *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier: identifier];
	[apps makeObjectsPerformSelector: @selector(terminate)];
	
	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for QuitApplication actions is the name of the application to quit.", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Quit application with this name:", @"");
}

@end
