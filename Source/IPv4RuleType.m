//
//  IPv4RuleType.m
//  ControlPlane
//
//  Created by VladimirTechMan on 18 Apr 2013.
//
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import <arpa/inet.h>
#import "IPAddrEvidenceSource.h"
#import "IPv4RuleType.h"


@interface CachedIPv4RuleParams : NSObject
@end

@implementation CachedIPv4RuleParams {
@public
    in_addr_t subnet, mask;
    int index;
}
@end


@implementation IPv4RuleType {
    // For custom panel
    IBOutlet NSComboBox *addressComboBox;
    IBOutlet NSComboBox *netmaskComboBox;
}

+ (NSString *)panelNibName {
    return @"IPRule";
}

- (NSString *)name {
    return @"IP";
}

- (BOOL)parseParamsOf:(NSMutableDictionary *)rule toNetAddr:(in_addr_t *)addr andMask:(in_addr_t *)mask {
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

    *addr = (ruleIPAddr.s_addr & (*mask = ruleSubnetMask.s_addr));

    return YES;
}

- (BOOL)doParamsMatch:(CachedIPv4RuleParams *)params {
    NSArray *addresses = ((IPAddrEvidenceSource *) self.evidenceSource).packedIPv4Addresses;
    const NSUInteger index = (NSUInteger) params->index;
    if (index >= [addresses count]) {
        return NO;
    }

    PackedIPv4Address *ipv4 = (PackedIPv4Address *) addresses[index];
    return (([ipv4 inAddr]->s_addr & params->mask) == params->subnet);
}

- (BOOL)doesRuleMatch:(NSMutableDictionary *)rule {
    CachedIPv4RuleParams *cachedParams = rule[@"cachedParams"];
    if (cachedParams) {
        if ((cachedParams->index >= 0) && [self doParamsMatch:cachedParams]) {
            return YES;
        }
    } else {
        cachedParams = [[CachedIPv4RuleParams alloc] init];
        if (![self parseParamsOf:rule toNetAddr:&(cachedParams->subnet) andMask:&(cachedParams->mask)]) {
            return NO; // corrupted rule
        }
        rule[@"cachedParams"] = cachedParams;
    }

    cachedParams->index = -1;

    const in_addr_t subnet = cachedParams->subnet, mask = cachedParams->mask;

    NSArray *addresses = ((IPAddrEvidenceSource *) self.evidenceSource).packedIPv4Addresses;
    [addresses enumerateObjectsUsingBlock:^(PackedIPv4Address *addr, NSUInteger idx, BOOL *stop) {
        if (([addr inAddr]->s_addr & mask) == subnet) {
            cachedParams->index = (int) idx; // for quick matching on future calls
            *stop = YES;
        }
    }];

    return (cachedParams->index >= 0);
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
    NSArray *comp = [rule[@"parameter"] componentsSeparatedByString:@","];

    // Set IP address
	NSArray *currentAddresses = ((IPAddrEvidenceSource *) self.evidenceSource).stringIPv4Addresses;
	[addressComboBox removeAllItems];
    
	NSString *ipAddress = ([comp count] > 0) ? (comp[0]) : (nil);
	if (ipAddress) {
        if (![currentAddresses containsObject:ipAddress]) {
            [addressComboBox addItemWithObjectValue:ipAddress];
        }
    } else {
		ipAddress = ([currentAddresses count]) ? (currentAddresses[0]) : (@"");
    }

    if (currentAddresses) {
        [addressComboBox addItemsWithObjectValues:currentAddresses];
    }
    [addressComboBox setStringValue:ipAddress];

    // Set IP network mask
    NSArray *netmasks = @[ @"255.255.255.255", @"255.255.255.0", @"255.255.0.0", @"255.0.0.0" ];
    [netmaskComboBox removeAllItems];

    NSString *netMask = ([comp count] > 1) ? (comp[1]) : (nil);
    if (netMask) {
        if (![netmasks containsObject:netMask]) {
            [netmaskComboBox addItemWithObjectValue:netMask];
        }
    } else {
        netMask = @"255.255.255.255";
    }

    [netmaskComboBox addItemsWithObjectValues:netmasks];
    [netmaskComboBox setStringValue:NSLocalizedString(netMask, @"netmask")];
}

@end
