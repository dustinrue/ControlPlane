//
//  MonitorEvidenceSource.m
//  MarcoPolo
//
//  Created by David Symonds on 2/07/07.
//

#include <IOKit/graphics/IOGraphicsLib.h>
#import "MonitorEvidenceSource.h"


@implementation MonitorEvidenceSource

- (id)init
{
	if (!(self = [super init]))
		return nil;

	lock = [[NSLock alloc] init];
	monitors = [[NSMutableArray alloc] init];

	return self;
}

- (void)dealloc
{
	[super blockOnThread];

	[lock dealloc];
	[monitors dealloc];

	[super dealloc];
}

- (void)doUpdate
{
	if (!sourceEnabled) {
		[lock lock];
		[monitors removeAllObjects];
		[self setDataCollected:NO];
		[lock unlock];
		return;
	}

	CGDirectDisplayID displays[4];
	CGDisplayCount numDisplays = -1;

	if (CGGetOnlineDisplayList(4, displays, &numDisplays) != 0) {	// should be CGErrorSuccess, not 0
		NSLog(@"%@ >> CGGetOnlineDisplayList failed!", [self class]);
		return;
	}

#ifdef DEBUG_MODE
	NSLog(@"%@ ] %d display%s found.", [self class], numDisplays, numDisplays > 1 ? "s" : "");
#endif
	int i;
	NSMutableArray *display_array = [NSMutableArray arrayWithCapacity:numDisplays];
	for (i = 0; i < numDisplays; ++i) {
		CGDirectDisplayID display_id = displays[i];

		NSString *display_name = @"Unknown display";
		io_service_t dev = CGDisplayIOServicePort(display_id);
		NSDictionary *dict = (NSDictionary *) IODisplayCreateInfoDictionary(dev, kIODisplayOnlyPreferredName);
		if (!dict) {
			NSLog(@"%@ >> Couldn't get info about display with ID 0x%08x!", [self class], display_id);
			continue;
		}

		// Get the product name; should be something like "DELL 1907FP", in the current locale
		NSDictionary *subdict = [dict objectForKey:(NSString *) CFSTR(kDisplayProductName)];
		if (subdict && ([subdict count] > 0))
			display_name = [[subdict allValues] objectAtIndex:0];

		// Our unique identifier: product ID (built-in LCDs don't have serial numbers)
		NSNumber *display_serial = [dict objectForKey:(NSString *) CFSTR(kDisplayProductID)];

#ifdef DEBUG_MODE
		NSLog(@"%@ ] Display ID = 0x%08x: (%@) id = %@", [self class], display_id,
		      display_name, display_serial);
#endif
		[display_array addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			display_serial, @"serial", display_name, @"name", nil]];

		[dict release];
	}

	[lock lock];
	[monitors setArray:display_array];
	[self setDataCollected:([monitors count] > 0)];
	[lock unlock];
}

- (NSString *)name
{
	return @"Monitor";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	return NO;
//	if (!status)
//		return NO;
//	return [[rule objectForKey:@"parameter"] isEqualToString:status];
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	// XXX
	return NSLocalizedString(@"An attached monitor called", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions
{
	return [NSArray array];
//	return [NSArray arrayWithObjects:
//		[NSDictionary dictionaryWithObjectsAndKeys:
//			@"Power", @"type",
//			@"Battery", @"parameter",
//			NSLocalizedString(@"Battery", @""), @"description", nil],
//		[NSDictionary dictionaryWithObjectsAndKeys:
//			@"Power", @"type",
//			@"A/C", @"parameter",
//			NSLocalizedString(@"Power Adapter", @""), @"description", nil],
//		nil];
}

@end
