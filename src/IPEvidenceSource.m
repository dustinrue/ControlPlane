//
//  IPEvidenceSource.m
//  MarcoPolo
//
//  Created by David Symonds on 29/03/07.
//

#include <SystemConfiguration/SystemConfiguration.h>
#import "IPEvidenceSource.h"


#pragma mark C callbacks

static void ipChange(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info)
{
#ifdef DEBUG_MODE
	NSLog(@"ipChange called with changedKeys:\n%@", changedKeys);
#endif
	IPEvidenceSource *src = (IPEvidenceSource *) info;

	[NSThread detachNewThreadSelector:@selector(doUpdateWithArg:)
				 toTarget:src
			       withObject:nil];
}

@implementation IPEvidenceSource

- (id)init
{
	if (!(self = [super init]))
		return nil;

	lock = [[NSLock alloc] init];
	addresses = [[NSMutableArray alloc] init];

	// Register for asynchronous notifications
	SCDynamicStoreContext ctxt;
	ctxt.version = 0;
	ctxt.info = self;
	ctxt.retain = NULL;
	ctxt.release = NULL;
	ctxt.copyDescription = NULL;

	store = SCDynamicStoreCreate(NULL, CFSTR("MarcoPolo"), ipChange, &ctxt);
	runLoop = SCDynamicStoreCreateRunLoopSource(NULL, store, 0);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoop, kCFRunLoopCommonModes);
	NSArray *keys = [NSArray arrayWithObjects:
				@"State:/Network/Global/IPv4",
				//@"State:/Network/Interface/en0/Link",
				nil];
	SCDynamicStoreSetNotificationKeys(store, (CFArrayRef) keys, NULL);
	// TODO: catch errors

	return self;
}

- (void)dealloc
{
	[super blockOnThread];

	[lock dealloc];
	[addresses dealloc];

	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoop, kCFRunLoopCommonModes);
	CFRelease(runLoop);
	CFRelease(store);

	[super dealloc];
}

+ (NSArray *)enumerate
{
	NSArray *all = [[NSHost currentHost] addresses];
	NSMutableArray *subset = [NSMutableArray array];
	NSEnumerator *e = [all objectEnumerator];
	NSString *ip;

	while (ip = [[e nextObject] lowercaseString]) {
		// Localhost IPs (IPv4/IPv6)
		if ([ip hasPrefix:@"127.0.0."])		// RFC 33030
			continue;
		if ([ip isEqualToString:@"::1"])
			continue;

		// IPv6 multicast (RFC 4291, section 2.7)
		if ([ip hasPrefix:@"ff"])
			continue;

		// IPv4 Link-local address (RFC 3927)
		if ([ip hasPrefix:@"169.254."])
			continue;

		// IPv6 link-local unicast (RFC 4291, section 2.4)
		if ([ip hasPrefix:@"fe80:"])
			continue;

		[subset addObject:ip];
	}

	return subset;
}

- (void)doUpdate
{
	NSArray *addrs;

	if (sourceEnabled) {
		addrs = [[self class] enumerate];
#ifdef DEBUG_MODE
		NSLog(@"%@ >> found %d address(s).\n", [self class], [addrs count]);
#endif
	} else
		addrs = [NSArray array];

	[lock lock];
	[addresses setArray:addrs];
	[self setDataCollected:[addresses count] > 0];
	[lock unlock];
}

- (void)doUpdateWithArg:(id)arg
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self doUpdate];
	[pool release];
}

- (NSString *)name
{
	return @"IP";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	BOOL match = NO;

	[lock lock];
	NSEnumerator *en = [addresses objectEnumerator];
	NSString *ip;
	NSString *prefix = [rule objectForKey:@"parameter"];
	while ((ip = [en nextObject])) {
		if ([ip hasPrefix:prefix]) {
			match = YES;
			break;
		}
	}
	[lock unlock];

	return match;
}

- (NSArray *)getAddresses
{
	NSArray *arr;

	[lock lock];
	arr = [NSArray arrayWithArray:addresses];
	[lock unlock];

	return arr;
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"An assigned IP address starting with", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions
{
	NSMutableSet *prefixes = [NSMutableSet set];

	[lock lock];
	NSEnumerator *en = [addresses objectEnumerator];
	NSString *addr;
	while ((addr = [en nextObject])) {
		[prefixes addObject:addr];

		// If it's an IPv4 address, also suggest its containing /8, /16 and /24 subnets
		NSArray *components = [addr componentsSeparatedByString:@"."];
		if ([components count] == 4) {
			int parts[4];
			parts[0] = [[components objectAtIndex:0] intValue];
			parts[1] = [[components objectAtIndex:1] intValue];
			parts[2] = [[components objectAtIndex:2] intValue];

			[prefixes addObject:[NSString stringWithFormat:@"%d.%d.%d.",
				parts[0], parts[1], parts[2]]];
			[prefixes addObject:[NSString stringWithFormat:@"%d.%d.",
				parts[0], parts[1]]];
			[prefixes addObject:[NSString stringWithFormat:@"%d.",
				parts[0]]];
		}
	}
	[lock unlock];

	// TODO: remove duplicates

	// Now turn that set of NSString objects into an array of NSDictionary objects
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[prefixes count]];
	NSArray *sorted_prefixes = [[prefixes allObjects] sortedArrayUsingSelector:@selector(compare:)];
	en = [sorted_prefixes objectEnumerator];
	while ((addr = [en nextObject])) {
		[ret addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			@"IP", @"type",
			addr, @"parameter",
			addr, @"description", nil]];
	}

	return ret;
}

@end
