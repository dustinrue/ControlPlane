//
//  IPEvidenceSource.m
//  ControlPlane
//
//  Created by David Symonds on 29/03/07.
//  Modified by Dustin Rue on 27/08/11.
//

#import <SystemConfiguration/SystemConfiguration.h>
#import "IPEvidenceSource.h"
#import "DSLogger.h"
#import <stdio.h>


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

	while ((ip = [[e nextObject] lowercaseString])) {
		// Localhost IPs (IPv4/IPv6)
		if ([ip hasPrefix:@"127.0.0."])		// RFC 3330
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
	DSLog(@"%@ >> found %lu address(s).", [self class], [addrs count]);
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

	store = SCDynamicStoreCreate(NULL, CFSTR("ControlPlane"), ipChange, &ctxt);
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
	if (![dict objectForKey:@"description"])
		[dict setValue:param forKey:@"description"];

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
    int i;
    NSInteger networkOctetPosition = 0;

    // TODO: add proper IPV6 support
	BOOL match = NO;

    // this grabs the IP address from the rule, will look something like
    // 192.168.0.0 and 255.255.255.0
	NSArray *comp = [[rule valueForKey:@"parameter"] componentsSeparatedByString:@","];
    
	if ([comp count] != 2)
		return NO;	// corrupted rule
	
	[lock lock];
    
    // now ControlPlane will determine if the IP address fits in the
    // network range provided in the rule
    
    // split the rule netmask into an array we can walk later
    NSArray *ruleNetmaskArray = [[comp objectAtIndex:1] componentsSeparatedByString:@"."];
    networkOctetPosition = [self findInterestingOctet:ruleNetmaskArray];
    
    // determine of the rule is a host address (netmask is 255.255.255.255)
    bool isHostAddress = [self isHostAddress:[comp objectAtIndex:1]];
    
	NSEnumerator *en = [addresses objectEnumerator];
	NSString *ip;

	while ((ip = [en nextObject])) {
#ifdef DEBUG_MODE
        DSLog(@"checking %@ to see if it matches against %@/%@",ip, [comp objectAtIndex:0], [comp objectAtIndex:1]);
#endif
        // if the rule is for a host address
        // then we can simply match the whole string wholesale and
        // then GTFO

        if (isHostAddress && [[comp objectAtIndex:0] isEqualToString:ip]) {
#ifdef DEBUG_MODE
            DSLog(@"matching on host address");
#endif
            match = YES;
            break;
        }
        else if (isHostAddress) {
            break;
        }

#ifdef DEBUG_MODE
        DSLog(@"checking %@ to see if it matches against %@/%@",ip, [comp objectAtIndex:0], [comp objectAtIndex:1]);
#endif

        
        // if we're here, then we have a network range we have to figure out
        // get the current ip we're checking, break it up into an array
        NSArray *currentIPArray   = [ip componentsSeparatedByString:@"."];
        NSArray *ruleIPArray      = [[comp objectAtIndex:0] componentsSeparatedByString:@"."];
        
        
        for (i = 0; i < 4; ++i) {
            // if i is less than our interesting octet then we can just compare the values directly
            if (i < networkOctetPosition) {
#ifdef DEBUG_MODE
                DSLog(@"checking %d and %d",[[currentIPArray objectAtIndex:i] intValue], [[ruleIPArray objectAtIndex:i] intValue]);
#endif
                if ([[currentIPArray objectAtIndex:i] intValue] != [[ruleIPArray objectAtIndex:i] intValue])
                    break;
                continue;
            }
            else {
#ifdef DEBUG_MODE
                DSLog(@"subnet mask octet is not 255, doing host checks for %@", ip);
#endif
            }
            

            // if the final netmask is 0 and everything else has matched up to this
            // point then we know that the IP the machine has matches the rule
            if ([[ruleNetmaskArray objectAtIndex:i] intValue] == 0) {
#ifdef DEBUG_MODE
                DSLog(@"%@ matches current rule", ip);
#endif
                match = YES;
                break;
            }
            else {
                // we must calculate what network the machine is on vs the 
                // network the rule says we're looking for
#ifdef DEBUG_MODE
                DSLog(@"checking %@ for match because it is on the same subnet (%d vs %d) as the rule", ip,  [[currentIPArray objectAtIndex:i] intValue] & [[ruleNetmaskArray objectAtIndex:i] intValue], [[ruleIPArray objectAtIndex:i] intValue] & [[ruleNetmaskArray objectAtIndex:i] intValue]);
#endif
                if (([[ruleIPArray objectAtIndex:i] intValue] & [[ruleNetmaskArray objectAtIndex:i] intValue])  == ([[currentIPArray objectAtIndex:i] intValue] & [[ruleNetmaskArray objectAtIndex:i] intValue])) {
                    // if these are equal then the machine is sitting on the same network as the rule
#ifdef DEBUG_MODE
                    DSLog(@"%@ matches because it is on the same subnet as the rule", ip);
#endif
                    match = YES;
                    break;
                }
                else {
#ifdef DEBUG_MODE
                    DSLog(@"%@ doesn't match rule %@/%@", ip, [comp objectAtIndex:0], [comp objectAtIndex:1]);
#endif
                    match = NO;
                    break;
                }
            }

        }

	}
	[lock unlock];


	return match;
}


// walks an array and returns which octet of subnetmask is of interest (not 255)
- (NSInteger) findInterestingOctet:(NSArray *)netmaskArray {
    for (NSUInteger i = 0; i < [netmaskArray count]; i++) {     
        if ([[netmaskArray objectAtIndex:i] intValue] != 255) {
            return i;
        }
    }
    // if we get here then it is a 32bit mask (255.255.255.255)
    return -1;
}

- (BOOL) isHostAddress:(NSString *) ipAddress {
    return ([ipAddress isEqualToString:@"255.255.255.255"]);
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Assigned IP Address", @"");
}


@end
