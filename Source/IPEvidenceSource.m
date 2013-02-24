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
    
	NSEnumerator *en = [addresses objectEnumerator];
	NSString *ip;

	while ((ip = [en nextObject]) && !match) {
        if ([self isIp:ip inRuleIp:[comp objectAtIndex:0] withSubnetMask:[comp objectAtIndex:1]])
            match = YES;
	}
	[lock unlock];


	return match;
}


- (NSString *) friendlyName {
    return NSLocalizedString(@"Assigned IP Address", @"");
}

- (BOOL) isIp:(NSString *)ipAddress inRuleIp:(NSString *)ruleIp withSubnetMask:(NSString *) ruleSubnet {
    // this page was used as a reference for building this code
    // http://www.cisco.com/web/about/ac123/ac147/archived_issues/ipj_9-1/ip_addresses.html
    
    NSArray *ipExploded = [ipAddress componentsSeparatedByString:@"."];
    NSArray *ruleIpExploded = [ruleIp componentsSeparatedByString:@"."];
    NSArray *netmaskExploded = [ruleSubnet componentsSeparatedByString:@"."];
    
    // in a CIDR network, these are the only valid values for a subnet
    NSArray *validSubnetValues = @[@0, @128, @192, @224, @240, @248, @252, @254, @255];
    
    // used as a lookup that converts a calculated jump size to the distance
    // between networks.  For example, if you have a network 10.0.0.0 with netmask 255.255.252.0
    // the prefix length value would calculate to /22.  22 % 8 is 6, 4 is in position 6 of the array below.
    // This means that there is a new network every 4th step from 0, like so
    // 10.0.0.0 - 10.0.3.255
    // 10.0.4.0 - 10.0.7.255
    // 10.0.8.0 - 10.0.11.255
    // Refer to the link above for more information
    NSArray *jump_sizes = @[@256, @128, @64, @32, @16, @8, @4, @2, @1];
    
    // we're going to determine the prefix length (the /24 part of 192.168.0.0/24 is the "prefix")
    // this makes calcuating some things later on easier.  It always starts with 8 because the
    // largest net mask is 255.0.0.0 (255 = 8 bits)
    int prefix = 8;
    
    // working_octet represents which octect of the ip address contains hosts and not just
    // the network
    int working_octet = 0;
    
    if ([[netmaskExploded objectAtIndex:0] intValue] != 255) {
        DSLog(@"invalid subnet mask in rule");
        return NO;
    }
    
    if ([validSubnetValues containsObject:[NSNumber numberWithInt:[[netmaskExploded objectAtIndex:1] intValue]]]) {
        prefix = prefix + [self calculatePrefixLengthForOctet:[[netmaskExploded objectAtIndex:1] intValue]];
    }
    else {
        DSLog(@"invalid subnet mask in rule");
        return NO;
    }
    
    if ([validSubnetValues containsObject:[NSNumber numberWithInt:[[netmaskExploded objectAtIndex:2] intValue]]]) {
        prefix = prefix + [self calculatePrefixLengthForOctet:[[netmaskExploded objectAtIndex:2] intValue]];
    }
    else {
        DSLog(@"invalid subnet mask in rule");
        return NO;
    }
    
    if ([validSubnetValues containsObject:[NSNumber numberWithInt:[[netmaskExploded objectAtIndex:3] intValue]]]) {
        prefix = prefix + [self calculatePrefixLengthForOctet:[[netmaskExploded objectAtIndex:3] intValue]];
    }
    else {
        DSLog(@"invalid subnet mask in rule");
        return NO;
    }
    
    // what ever prefix's value is now, that'd be the short hand (address prefix length) of the
    // subnet.  A class A would be /8, B /16 and C /24.  
    // if prefix is 32, then we're looking for a specific host address
    // and we can leave early if the ip address matches the rule ip address
    if (prefix == 32) {
        if ([ipAddress isEqualToString:ruleIp])
            return YES;
    }
    
    // based on the subnet mask, how many octets of the assigned IP address
    // and the rule IP must match?  This is based on the prefix.  Again, if dealing
    // with a simple class C network then the first 3 octets of the net mask would be
    // 255.255.255.0 meaning the first 3 octets of the assigned IP must match the
    // first 3 octets of the rule IP
    
    if (prefix % 8 != 0)
        working_octet = floor(prefix / 8);
    else {
        working_octet = prefix / 8;
    }
    
    for (int i = 0; i < working_octet; i++) {
        if (![[ipExploded objectAtIndex:i] isEqualToString:[ruleIpExploded objectAtIndex:i]])
            return NO;
    }
    

    // calculate how large the a network is
    int jump_size = prefix % 8; // distance between subnets
    
    // if we've made it this far and the "jump size" is 0, then the IP
    // fits within the range provided and we have a match.  This will happen
    // when we've hit on one of the original A, B or C classes of networks
    if (jump_size == 0)
        return YES;
    
    // if jump size is anything other than 0 then it gets more difficult
    // we convert the jump size we have to a value that represents the distance
    // between networks as described above.
    jump_size = [[jump_sizes objectAtIndex:jump_size] intValue];
    
    //NSLog(@"the interesting octet for %@ is %d, jump size is %d", ipAddress, [[ipExploded objectAtIndex:working_octet] intValue], jump_size);
    
    for (int i = 0; i < 256; i = i + jump_size) {
        
        // just as well leave if i is larger than the rule's interesting octet
        if (i > [[ruleIpExploded objectAtIndex:working_octet] intValue])
            return NO;
        // test to see if the rule exists in a valid network
        //NSLog(@"checking if rule's %d fits in %d - %d", [[ruleIpExploded objectAtIndex:working_octet] intValue], i, i + jump_size);
        if ([[ruleIpExploded objectAtIndex:working_octet] intValue] >= i && [[ruleIpExploded objectAtIndex:working_octet] intValue] < i + jump_size) {
            // if the rule matches, lets see if the assigned ip address does too
            //NSLog(@"checking if assigned ip's %d fits in %d - %d", [[ipExploded objectAtIndex:working_octet] intValue], i, i + jump_size);
            if ([[ipExploded objectAtIndex:working_octet] intValue] >= i && [[ipExploded objectAtIndex:working_octet] intValue] < i + jump_size) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (int) calculatePrefixLengthForOctet:(int) octet {
    //NSLog(@"calculating for %d", octet);
    int one_count = 0;
    
    if (octet - 128 >= 0)
        one_count++;
    
    if (octet - 192 >= 0)
        one_count++;
    
    if (octet - 224 >= 0)
        one_count++;
    
    if (octet - 240 >= 0)
        one_count++;
    
    if (octet - 248 >= 0)
        one_count++;
    
    if (octet - 252 >= 0)
        one_count++;
    
    if (octet - 254 >= 0)
        one_count++;
    
    if (octet - 255 >= 0)
        one_count++;
    
    //NSLog(@"returning %d", one_count);
    return one_count;
        
}

@end
