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

	// This is spun off into a separate thread because DNS delays, etc., would
	// hold up the main thread, causing UI hanging.
	[NSThread detachNewThreadSelector:@selector(doFullUpdate:)
				 toTarget:src
			       withObject:nil];
}

#pragma mark -

@interface IPEvidenceSource (Private)

- (BOOL)parseAddress:(NSString *)ipAddress intoArray:(unsigned char *)bytes;

@end

#pragma mark -

@implementation IPEvidenceSource

- (id)init
{
	if (!(self = [super initWithNibNamed:@"IPRule"]))
		return nil;

	lock = [[NSLock alloc] init];
	addresses = [[NSMutableArray alloc] init];

	return self;
}

- (void)dealloc
{
	[lock release];
	[addresses release];

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

- (void)doFullUpdate:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self setThreadNameFromClassName];

	NSArray *addrs = [[self class] enumerate];
#ifdef DEBUG_MODE
	NSLog(@"%@ >> found %d address(s).", [self class], [addrs count]);
#endif

	[lock lock];
	[addresses setArray:addrs];
	[self setDataCollected:[addresses count] > 0];
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

	store = SCDynamicStoreCreate(NULL, CFSTR("MarcoPolo"), ipChange, &ctxt);
	runLoop = SCDynamicStoreCreateRunLoopSource(NULL, store, 0);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoop, kCFRunLoopCommonModes);
	NSArray *keys = [NSArray arrayWithObjects:
					  @"State:/Network/Global/IPv4",
					//@"State:/Network/Interface/en0/Link",
		nil];
	SCDynamicStoreSetNotificationKeys(store, (CFArrayRef) keys, NULL);
	// TODO: catch errors

	// (see comment in ipChange function to see why we don't call it directly)
	[NSThread detachNewThreadSelector:@selector(doFullUpdate:)
				 toTarget:self
			       withObject:nil];

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
	[addresses removeAllObjects];
	[self setDataCollected:NO];
	[lock unlock];

	running = NO;
}

- (NSMutableDictionary *)readFromPanel
{
	NSMutableDictionary *dict = [super readFromPanel];

	NSString *param = [NSString stringWithFormat:@"%@,%@", ruleIP, ruleNetmask];
	[dict setValue:param forKey:@"parameter"];
//	if (![dict objectForKey:@"description"])
//		[dict setValue:param forKey:@"description"];

	return dict;
}

- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type
{
	[super writeToPanel:dict usingType:type];

	[lock lock];
	NSArray *arr = [NSArray arrayWithArray:addresses];
	[lock unlock];

	[ruleComboBox removeAllItems];
	[ruleComboBox addItemsWithObjectValues:arr];

	NSString *addr = @"", *nmask = @"255.255.255.255";
	if ([arr count] > 0)
		addr = [arr objectAtIndex:0];
	if ([dict objectForKey:@"parameter"]) {
		NSArray *comp = [[dict valueForKey:@"parameter"] componentsSeparatedByString:@","];
		if ([comp count] == 2) {
			addr = [comp objectAtIndex:0];
			nmask = [comp objectAtIndex:1];

			if (![[ruleComboBox objectValues] containsObject:addr])
				[ruleComboBox addItemWithObjectValue:addr];
			[ruleComboBox selectItemWithObjectValue:addr];
		}
	}
	[self setValue:addr forKey:@"ruleIP"];
	[self setValue:nmask forKey:@"ruleNetmask"];
}

- (NSString *)name
{
	return @"IP";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	BOOL match = NO;

	NSArray *comp = [[rule valueForKey:@"parameter"] componentsSeparatedByString:@","];
	if ([comp count] != 2)
		return NO;	// corrupted rule

	unsigned char addr[4], nmask[4];
	if (![self parseAddress:[comp objectAtIndex:0] intoArray:addr])
		return NO;
	if (![self parseAddress:[comp objectAtIndex:1] intoArray:nmask])
		return NO;

	[lock lock];
	NSEnumerator *en = [addresses objectEnumerator];
	NSString *ip;
	while ((ip = [en nextObject])) {
		unsigned char real_addr[4];
		if (![self parseAddress:ip intoArray:real_addr])
			continue;
		int i;
		for (i = 0; i < 4; ++i) {
			if ((addr[i] & nmask[i]) != (real_addr[i] & nmask[i]))
				break;
		}
		if (i == 4) {
			match = YES;
			break;
		}
	}
	[lock unlock];

	return match;
}

// Parse a string that looks like an IP address, or the start of one.
// If it's a prefix string, it'll be filled with zeros.
- (BOOL)parseAddress:(NSString *)ipAddress intoArray:(unsigned char *)bytes
{
	NSArray *comp = [ipAddress componentsSeparatedByString:@"."];
	if ([comp count] > 4)
		return NO;

	// TODO: check that they are all numbers?
	int i;
	memset(bytes, 0, 4);
	for (i = 0; i < [comp count]; ++i) {
		int x = [[comp objectAtIndex:i] intValue];
		if ((x == INT_MIN) || (x == INT_MAX))
			continue;
		bytes[i] = x;
	}
	return YES;
}

@end
