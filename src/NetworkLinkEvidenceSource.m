//
//  NetworkLinkEvidenceSource.m
//  MarcoPolo
//
//  Created by Mark Wallis on 25/07/07.
//

#include <SystemConfiguration/SystemConfiguration.h>
#import "NetworkLinkEvidenceSource.h"


#pragma mark C callbacks

static void linkChange(SCDynamicStoreRef store, CFArrayRef changedKeys,  void *info)
{
	NetworkLinkEvidenceSource *src = (NetworkLinkEvidenceSource *) info;

	// This is spun off into a separate thread because DNS delays, etc., would
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
	SCDynamicStoreContext ctxt;
	ctxt.version = 0;
	ctxt.info = self;
	ctxt.retain = NULL;
	ctxt.release = NULL;
	ctxt.copyDescription = NULL;
	SCDynamicStoreRef newStore = SCDynamicStoreCreate(NULL, CFSTR("MarcoPolo"), NULL, &ctxt);

	NSArray *all = (NSArray *)SCNetworkInterfaceCopyAll();
	NSMutableArray *subset = [NSMutableArray array];
	NSEnumerator *e = [all objectEnumerator];
	SCNetworkInterfaceRef inter;

	while (inter = (SCNetworkInterfaceRef)[e nextObject]) {
		NSString *opt;
		NSString *name = (NSString *)SCNetworkInterfaceGetBSDName(inter);
		if ([@"en" isEqualToString:[name substringToIndex:2]])
		{
			CFStringRef key = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("State:/Network/Interface/%@/Link"), name);
			CFDictionaryRef current = SCDynamicStoreCopyValue(newStore, key);
			if (CFDictionaryGetValue(current, CFSTR("Active")) == kCFBooleanTrue)
				opt = [NSString stringWithFormat:@"+%@", name];
			else
				opt = [NSString stringWithFormat:@"-%@", name];

			[subset addObject:opt];
		}
	}

	[all release];
	return subset;
}

- (void)doFullUpdate:(id)sender
{
	NSArray *inters;

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	inters = [[self class] enumerate];

	[lock lock];
	[interfaces setArray:inters];
	[self setDataCollected:[interfaces count] > 0];
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

	NSArray *all = (NSArray *)SCNetworkInterfaceCopyAll();
	NSEnumerator *e = [all objectEnumerator];
	NSMutableArray *monInters = [NSMutableArray arrayWithCapacity:0];

	SCNetworkInterfaceRef inter;
	while (inter = (SCNetworkInterfaceRef)[e nextObject]) {
		NSString *name = (NSString *)SCNetworkInterfaceGetBSDName(inter);
		if ([@"en" isEqualToString:[name substringToIndex:2]])
		{
			[monInters addObject:[NSString stringWithFormat:@"State:/Network/Interface/%@/Link", name]];
		}
	}

	store = SCDynamicStoreCreate(NULL, CFSTR("MarcoPolo"), linkChange, &ctxt);
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

	NSArray *comp = [[rule valueForKey:@"parameter"] componentsSeparatedByString:@","];
	if ([comp count] != 1)
		return NO;	// corrupted rule

	[lock lock];
	NSEnumerator *en = [interfaces objectEnumerator];
	NSString *inter;
	while ((inter = [en nextObject])) {
		if ([inter isEqualToString:[comp objectAtIndex:0]] == TRUE)
			match = YES;
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
	NSMutableArray *sugg = [NSMutableArray arrayWithCapacity:0];
	NSArray *all = (NSArray *)SCNetworkInterfaceCopyAll();
	NSEnumerator *e = [all objectEnumerator];
	NSString *activeDesc, *inactiveDesc, *activeName, *inactiveName, *name;

	SCNetworkInterfaceRef inter;
	while (inter = (SCNetworkInterfaceRef)[e nextObject]) {
		name = (NSString *)SCNetworkInterfaceGetBSDName(inter);
		if ([@"en" isEqualToString:[name substringToIndex:2]])
		{
			activeDesc   = [NSString stringWithFormat:@"%@ link active", name];
			inactiveDesc = [NSString stringWithFormat:@"%@ link inactive", name];
			activeName   = [NSString stringWithFormat:@"+%@", name];
			inactiveName = [NSString stringWithFormat:@"-%@", name];

			[sugg addObject:[NSDictionary dictionaryWithObjectsAndKeys:
				@"NetworkLink", @"type",
				activeName, @"parameter",
				NSLocalizedString(activeDesc, @""), @"description", nil]];
			[sugg addObject:[NSDictionary dictionaryWithObjectsAndKeys:
				@"NetworkLink", @"type",
				inactiveName, @"parameter",
				NSLocalizedString(inactiveDesc, @""), @"description", nil]];
		}
	}
	[all release];
	[lock unlock];


	return sugg;
}

@end
