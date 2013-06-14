//
//  MonitorEvidenceSource.m
//  ControlPlane
//
//  Created by David Symonds on 2/07/07.
//

#import <IOKit/graphics/IOGraphicsLib.h>
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
	[lock release];
	[monitors release];

	[super dealloc];
}


- (NSString *) description {
    return NSLocalizedString(@"Create rules based on monitors attached to your Mac.", @"");
}

- (void)doUpdate
{
	CGDirectDisplayID displays[4];
	CGDisplayCount numDisplays = -1;

	if (CGGetOnlineDisplayList(4, displays, &numDisplays) != 0) {	// should be CGErrorSuccess, not 0
		NSLog(@"%@ >> CGGetOnlineDisplayList failed!", [self class]);
		return;
	}

#ifdef DEBUG_MODE
	NSLog(@"%@ ] %d display%s found.", [self class], numDisplays, numDisplays > 1 ? "s" : "");
#endif
	
	NSMutableArray *display_array = [NSMutableArray arrayWithCapacity:numDisplays];
	for (CGDisplayCount i = 0; i < numDisplays; ++i) {
		CGDirectDisplayID display_id = displays[i];

		NSString *display_name = NSLocalizedString(@"(Unnamed display)", "String for unnamed monitors");
		io_service_t dev = CGDisplayIOServicePort(display_id);
		NSDictionary *dict = (NSDictionary *) IODisplayCreateInfoDictionary(dev, kIODisplayOnlyPreferredName);
		if (!dict) {
			NSLog(@"%@ >> Couldn't get info about display with ID 0x%08x!", [self class], display_id);
			continue;
		}

		// Get the product name; should be something like "DELL 1907FP", in the current locale
		NSDictionary *subdict = [dict objectForKey:(NSString *) CFSTR(kDisplayProductName)];

        @try {
            if (subdict && ([subdict count] > 0))
                display_name = [[subdict allValues] objectAtIndex:0];
        }
        @catch (NSException *exception) {
            NSLog(@"failed to get monitor type/name");
        }
		

		// Our unique identifier: product ID (built-in LCDs don't have serial numbers)
		NSNumber *display_serial = [dict objectForKey:(NSString *) CFSTR(kDisplayProductID)];

#ifdef DEBUG_MODE
		NSLog(@"%@ ] Display ID = 0x%08x: (%@) id = %@", [self class], display_id,
		      display_name, display_serial);
#endif
		[display_array addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[display_serial stringValue], @"serial", display_name, @"name", nil]];

		[dict release];
	}

	[lock lock];
	[monitors setArray:display_array];
	[self setDataCollected:[monitors count] > 0];
	[lock unlock];
}

- (void)clearCollectedData
{
	[lock lock];
	[monitors removeAllObjects];
	[self setDataCollected:NO];
	[lock unlock];
}

- (NSString *)name
{
	return @"Monitor";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	BOOL match = NO;

	[lock lock];
	NSEnumerator *en = [monitors objectEnumerator];
	NSDictionary *mon;
	NSString *serial = [rule valueForKey:@"parameter"];
	while ((mon = [en nextObject])) {
		if ([[mon valueForKey:@"serial"] isEqualToString:serial]) {
			match = YES;
			break;
		}
	}
	[lock unlock];

	return match;
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"An attached monitor named", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions
{
	NSMutableArray *arr = [NSMutableArray arrayWithCapacity:[monitors count]];

	[lock lock];
	NSEnumerator *en = [monitors objectEnumerator];
	NSDictionary *mon;
	while ((mon = [en nextObject])) {
		NSString *name = [mon valueForKey:@"name"];
		NSString *serial = [mon valueForKey:@"serial"];

		[arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			@"Monitor", @"type",
			serial, @"parameter",
			name, @"description", nil]];
	}
	[lock unlock];

	return arr;
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Attached Monitor", @"");
}
@end
