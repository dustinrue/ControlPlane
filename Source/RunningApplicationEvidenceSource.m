//
//  RunningApplicationEvidenceSource.m
//  ControlPlane
//
//  Created by David Symonds on 23/5/07.
//

#import "RunningApplicationEvidenceSource.h"


@implementation RunningApplicationEvidenceSource

- (id)init
{
	if (!(self = [super init]))
		return nil;

	applications = [[NSMutableArray alloc] init];

	return self;
}

- (void)dealloc
{
	[applications release];

	[super dealloc];
}

- (void)doFullUpdate
{
	NSArray *app_list = [[NSWorkspace sharedWorkspace] launchedApplications];
	NSMutableArray *apps = [[NSMutableArray alloc] initWithCapacity:[app_list count]];
	NSEnumerator *en = [app_list objectEnumerator];
	NSDictionary *dict;
	while ((dict = [en nextObject])) {
		NSString *identifier = [dict valueForKey:@"NSApplicationBundleIdentifier"];
		NSString *name = [dict valueForKey:@"NSApplicationName"];
		[apps addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			identifier, @"identifier", name, @"name", nil]];
	}

	[lock lock];
	[applications setArray:apps];
	[self setDataCollected:[applications count] > 0];
#ifdef DEBUG
	//NSLog(@"Running apps:\n%@", applications);
#endif
	[lock unlock];
	
	[apps release];
}

- (void)start
{
	if (running)
		return;

	// register for notifications
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
							       selector:@selector(doFullUpdate)
								   name:NSWorkspaceDidLaunchApplicationNotification
								 object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
							       selector:@selector(doFullUpdate)
								   name:NSWorkspaceDidTerminateApplicationNotification
								 object:nil];

	[self doFullUpdate];

	running = YES;
}

- (void)stop
{
	if (!running)
		return;

	// remove notifications
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self
								      name:nil
								    object:nil];

	[lock lock];
	[applications removeAllObjects];
	[self setDataCollected:NO];
	[lock unlock];

	running = NO;
}

- (NSString *)name
{
	return @"RunningApplication";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	NSString *param = [rule valueForKey:@"parameter"];
	BOOL match = NO;

	[lock lock];
	NSEnumerator *en = [applications objectEnumerator];
	NSDictionary *dict;
	while ((dict = [en nextObject])) {
		if ([[dict valueForKey:@"identifier"] isEqualToString:param]) {
			match = YES;
			break;
		}
	}
	[lock unlock];

	return match;
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"The following application running", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions
{
	[lock lock];
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[applications count]];

	NSEnumerator *en = [applications objectEnumerator];
	NSDictionary *dict;
	while ((dict = [en nextObject])) {
		NSString *identifier = [dict valueForKey:@"identifier"];
		NSString *desc = [NSString stringWithFormat:@"%@ (%@)", [dict valueForKey:@"name"], identifier];
		[array addObject:
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"RunningApplication", @"type",
				identifier, @"parameter",
				desc, @"description", nil]];
	}
	[lock unlock];

	return array;
}

@end
