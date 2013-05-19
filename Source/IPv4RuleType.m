//
//  IPv4RuleType.m
//  ControlPlane
//
//  Created by VladimirTechMan on 18 Apr 2013.
//
//

#import <arpa/inet.h>
#import "IPAddrEvidenceSource.h"
#import "IPv4RuleType.h"


@implementation IPv4RuleType {
    // For custom panel
    IBOutlet NSComboBox *addressComboBox;
    IBOutlet NSComboBox *netmaskComboBox;
}

+ (NSString *)panelNibName {
    return @"IPRule";
}

- (NSString *)name {
    return NSLocalizedString(@"IP", @"");
}

- (void)dealloc {
    [super dealloc];
}

- (BOOL)parseParamsOf:(NSMutableDictionary *)rule toNetAddr:(in_addr_t *)addr andMask:(in_addr_t *)mask {
    NSNumber *cachedSubnet = rule[@"cachedSubnet"];
    NSNumber *cachedMask   = rule[@"cachedMask"];

    if (cachedSubnet && cachedMask) {
        *mask = (in_addr_t) [cachedMask unsignedIntValue];
        *addr = (in_addr_t) [cachedSubnet unsignedIntValue];
        return YES;
    }

	NSArray *comp = [rule[@"parameter"] componentsSeparatedByString:@","];
    
	if ([comp count] != 2) {
		return NO;	// corrupted rule
    }
    
    struct in_addr ruleIPAddr, ruleSubnetMask;
    if (inet_pton(AF_INET, [comp[0] UTF8String], &ruleIPAddr) != 1) {
        return NO;
    }
    if (inet_pton(AF_INET, [comp[1] UTF8String], &ruleSubnetMask) != 1) {
        return NO;
    }

    in_addr_t maskValue = ruleSubnetMask.s_addr, subnetAddrValue = (ruleIPAddr.s_addr & maskValue);

    *mask = maskValue;
    rule[@"cachedMask"] = @(maskValue);

    *addr = subnetAddrValue;
    rule[@"cachedSubnet"] = @(subnetAddrValue);

    return YES;
}

- (BOOL)doesAddressAtIndex:(NSUInteger)index matchNetworkAddress:(in_addr_t)address usingMask:(in_addr_t)mask {

    NSArray *addresses = ((IPAddrEvidenceSource *) self.evidenceSource).packedIPv4Addresses;
    if (index < [addresses count]) {
        struct in_addr ipv4;
        [(NSValue *) addresses[index] getValue:&ipv4];
        return ((ipv4.s_addr & mask) == address);
    }

    return NO;
}

- (BOOL)doesRuleMatch:(NSMutableDictionary *)rule {
    in_addr_t ruleSubnet, mask;
    if (![self parseParamsOf:rule toNetAddr:&ruleSubnet andMask:&mask]) {
        return NO; // corrupted rule
    }

    NSNumber *index = rule[@"cachedIndex"];
    if (index && [self doesAddressAtIndex:[index unsignedIntegerValue]
                        matchNetworkAddress:ruleSubnet usingMask:mask]) {
        return YES;
    }

    __block BOOL match = NO;

    NSArray *addresses = ((IPAddrEvidenceSource *) self.evidenceSource).packedIPv4Addresses;
    [addresses enumerateObjectsUsingBlock:^(NSValue *packedIPAddr, NSUInteger idx, BOOL *stop) {
        struct in_addr ipv4;
        [packedIPAddr getValue:&ipv4];
        if ((ipv4.s_addr & mask) == ruleSubnet) {
            *stop = match = YES;
            rule[@"cachedIndex"] = @(idx); // for quick matching on future calls
        }
    }];

    return match;
}

static BOOL isValidIPv4Address(NSString *value) {
    struct in_addr ipv4;
    return (inet_pton(AF_INET, [value UTF8String], &ipv4) == 1);
}

static BOOL isValidIPv4NetworkMask(NSString *value) {
    struct in_addr ipv4;
    if ((inet_pton(AF_INET, [value UTF8String], &ipv4) != 1) || (ipv4.s_addr == 0x0)) {
        return NO;
    }

    in_addr_t mask = ntohl(ipv4.s_addr);
    in_addr_t oneBit = 0x1;
    unsigned int count = 32u;

    while ((count > 0u) && ((mask & oneBit) == 0x0)) { // skip all leading zero bits in the mask
        oneBit <<= 1;
        --count;
    }

    while ((count > 0u) && ((mask & oneBit) != 0x0)) { // all remaning bits in a valid netmask may not be zero
        oneBit <<= 1;
        --count;
    }

    return (count == 0u);
}

- (BOOL)validatePanelParams {
    NSString *addr = [addressComboBox stringValue];
    addr = [addr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [addressComboBox setStringValue:addr];

    NSString *mask = [netmaskComboBox stringValue];
    mask = [mask stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [netmaskComboBox setStringValue:mask];

    if (![addr length]) {
        [[self class] alertOnInvalidParamValueWith:NSLocalizedString(@"IP address cannot be empty", @"")];
        return NO;
    }
    if (!isValidIPv4Address(addr)) {
        [[self class] alertOnInvalidParamValueWith:NSLocalizedString(@"Not a valid IPv4 address", @"")];
        return NO;
    }

    if (![mask length]) {
        [[self class] alertOnInvalidParamValueWith:NSLocalizedString(@"Network mask cannot be empty", @"")];
        return NO;
    }
    if (!isValidIPv4NetworkMask(mask)) {
        [[self class] alertOnInvalidParamValueWith:NSLocalizedString(@"Not a valid IPv4 network mask", @"")];
        return NO;
    }
    
    return YES;
}

- (void)readFromPanelInto:(NSMutableDictionary *)rule {
    [super readFromPanelInto:rule];
    rule[@"parameter"] = [NSString stringWithFormat:@"%@,%@",
                          [addressComboBox stringValue], [netmaskComboBox stringValue]];
}

- (NSString *)getDefaultDescription:(NSDictionary *)rule {
    return rule[@"parameter"];
}

- (void)writeToPanel:(NSDictionary *)rule {
    [super writeToPanel:rule];
	NSArray *currentAddresses = ((IPAddrEvidenceSource *) self.evidenceSource).stringIPv4Addresses;
    NSArray *comp = [rule[@"parameter"] componentsSeparatedByString:@","];

    // Set IP address
	[addressComboBox removeAllItems];
    if (currentAddresses) {
        [addressComboBox addItemsWithObjectValues:currentAddresses];
    }
    
	NSString *ipAddress = ([comp count] > 0) ? (comp[0]) : (nil);
	if (ipAddress) {
        if (![currentAddresses containsObject:ipAddress]) {
            [addressComboBox addItemWithObjectValue:ipAddress];
        }
    } else {
		ipAddress = ([currentAddresses count]) ? (currentAddresses[0]) : (@"");
    }

    [addressComboBox setStringValue:ipAddress];

    // Set IP network mask
    [netmaskComboBox removeAllItems];
    [netmaskComboBox addItemsWithObjectValues:@[ @"255.255.255.255", @"255.255.255.0",
     @"255.255.0.0", @"255.0.0.0" ]]; // common netmasks
    
    NSString *netMask = ([comp count] > 1) ? (comp[1]) : (nil);
    if (netMask) {
        if (![[netmaskComboBox objectValues] containsObject:netMask]) {
            [netmaskComboBox addItemWithObjectValue:netMask];
        }
    } else {
        netMask = @"255.255.255.255";
    }

    [netmaskComboBox setStringValue:netMask];
}

@end
