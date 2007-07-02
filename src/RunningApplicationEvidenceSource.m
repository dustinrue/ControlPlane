//
//  RunningApplicationEvidenceSource.m
//  MarcoPolo
//
//  Created by David Symonds on 23/5/07.
//

#import <Cocoa/Cocoa.h>
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
	[super blockOnThread];

	[super dealloc];
}

- (void)doUpdate
{
	if (!sourceEnabled) {
		[applications removeAllObjects];
		[self setDataCollected:NO];
		return;
	}

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
#ifdef DEBUG_MODE
	//NSLog(@"Running apps:\n%@", applications);
#endif
	[lock unlock];
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
