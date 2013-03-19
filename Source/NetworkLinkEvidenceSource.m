//
//  NetworkLinkEvidenceSource.m
//  ControlPlane
//
//  Created by Mark Wallis on 25/07/07.
//  Tweaks by David Symonds on 25/07/07.
//

#import <SystemConfiguration/SystemConfiguration.h>
#import "NetworkLinkEvidenceSource.h"


#pragma mark C callbacks

static void linkChange(SCDynamicStoreRef store, CFArrayRef changedKeys,  void *info)
{
#ifdef DEBUG_MODE
	NSLog(@"linkChange called with changedKeys:\n%@", changedKeys);
#endif
	NetworkLinkEvidenceSource *src = (NetworkLinkEvidenceSource *) info;

	// This is spun off into a separate thread because any delays would
	// hold up the main thread, causing UI hanging.
	[NSThread detachNewThreadSelector:@selector(doFullUpdate:)
				 toTarget:src
			       withObject:nil];
}

@implementation NetworkLinkEvidenceSource

- (id)init
{
	if (!(self = [super init]))
		return nil;

	lock = [[NSLock alloc] init];
	interfaces = [[NSMutableArray alloc] init];

	return self;
}

- (void)dealloc
{
	[lock release];
	[interfaces release];

	[super dealloc];
}

+ (NSArray *)enumerate
{
	SCDynamicStoreContext ctxt = {0, self, NULL, NULL, NULL};
	SCDynamicStoreRef newStore = SCDynamicStoreCreate(NULL, CFSTR("ControlPlane"), NULL, &ctxt);

	NSMutableArray *subset = [NSMutableArray array];

	NSArray *all = (NSArray *) SCNetworkInterfaceCopyAll();
    for (id inter in all) {
		NSString *name = (NSString *) SCNetworkInterfaceGetBSDName((SCNetworkInterfaceRef) inter);
		NSString *key = [NSString stringWithFormat:@"State:/Network/Interface/%@/Link", name];
		CFDictionaryRef current = SCDynamicStoreCopyValue(newStore, (CFStringRef) key);
		if (current) {
            NSString *opt;
            if (CFDictionaryGetValue(current, CFSTR("Active")) == kCFBooleanTrue)
                opt = @"+";
            else
                opt = @"-";
            [subset addObject:[opt stringByAppendingString:name]];
            
            CFRelease(current);
		}
	}
	[all release];

    CFRelease(newStore);
    
	return subset;
}

- (void)doFullUpdate:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self setThreadNameFromClassName];

	NSArray *inters = [[self class] enumerate];

	[lock lock];
	[interfaces setArray:inters];
	[self setDataCollected:[interfaces count] > 0];
    //[[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
	[lock unlock];

	[pool release];
}

- (void)start
{
	if (running)
		return;

	// Register for asynchronous notifications
	SCDynamicStoreContext ctxt;
	ctxt.version = 0;
	ctxt.info = self;
	ctxt.retain = NULL;
	ctxt.release = NULL;
	ctxt.copyDescription = NULL;

	NSArray *all = (NSArray *) SCNetworkInterfaceCopyAll();
	NSEnumerator *e = [all objectEnumerator];
	NSMutableArray *monInters = [NSMutableArray arrayWithCapacity:0];

	SCNetworkInterfaceRef inter;
	while (inter = (SCNetworkInterfaceRef) [e nextObject]) {
		NSString *name = (NSString *) SCNetworkInterfaceGetBSDName(inter);
		[monInters addObject:[NSString stringWithFormat:@"State:/Network/Interface/%@/Link", name]];
	}

	store = SCDynamicStoreCreate(NULL, CFSTR("ControlPlane"), linkChange, &ctxt);
	runLoop = SCDynamicStoreCreateRunLoopSource(NULL, store, 0);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoop, kCFRunLoopCommonModes);
	NSArray *keys = monInters;

	SCDynamicStoreSetNotificationKeys(store, (CFArrayRef) keys, NULL);
	// TODO: catch errors

	// (see comment in linkChange function to see why we don't call it directly)
	[NSThread detachNewThreadSelector:@selector(doFullUpdate:)
				 toTarget:self
			       withObject:nil];

	[all release];

	running = YES;
}

- (void)stop
{
	if (!running)
		return;

	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoop, kCFRunLoopCommonModes);
	CFRelease(runLoop);
	CFRelease(store);

	[lock lock];
	[interfaces removeAllObjects];
	[self setDataCollected:NO];
	[lock unlock];

	running = NO;
}

- (NSString *)name
{
	return @"NetworkLink";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	BOOL match = NO;

	NSString *iface = [rule valueForKey:@"parameter"];

	[lock lock];
	NSEnumerator *en = [interfaces objectEnumerator];
	NSString *inter;
	while ((inter = [en nextObject])) {
		if ([inter isEqualToString:iface]) {
			match = YES;
			break;
		}
	}
	[lock unlock];

	return match;
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"Network link on interface", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions
{
	NSMutableArray *arr = [NSMutableArray array];
	NSArray *all = [(NSArray *) SCNetworkInterfaceCopyAll() autorelease];

	NSEnumerator *en = [all objectEnumerator];
	SCNetworkInterfaceRef inter;
	while ((inter = (SCNetworkInterfaceRef) [en nextObject])) {
		NSString *dev = (NSString *) SCNetworkInterfaceGetBSDName(inter);
		if (!dev)
			continue;
		NSString *name = (NSString *) SCNetworkInterfaceGetLocalizedDisplayName(inter);
		if (!name)
			name = [NSString stringWithFormat:@"%@?", dev];
		NSString *activeDesc = [NSString stringWithFormat:
			NSLocalizedString(@"%@ (%@) link active", @"In NetworkLinkEvidenceSource"), dev, name];
		NSString *inactiveDesc = [NSString stringWithFormat:
			NSLocalizedString(@"%@ (%@) link inactive", @"In NetworkLinkEvidenceSource"), dev, name];
		NSString *activeParam = [NSString stringWithFormat:@"+%@", dev];
		NSString *inactiveParam = [NSString stringWithFormat:@"-%@", dev];

		// Don't include interfaces that we couldn't enumerate
		if (![interfaces containsObject:activeParam] && ![interfaces containsObject:inactiveParam])
			continue;

		[arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			@"NetworkLink", @"type",
			activeParam, @"parameter",
			activeDesc, @"description", nil]];
		[arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			@"NetworkLink", @"type",
			inactiveParam, @"parameter",
			inactiveDesc, @"description", nil]];
	}

	return arr;
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Active Network Adapter", @"");
}

@end
