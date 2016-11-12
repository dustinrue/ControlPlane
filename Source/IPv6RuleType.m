//
//  IPv6RuleType.m
//  ControlPlane
//
//  Created by VladimirTechMan on 19 Apr 2013.
//
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import <arpa/inet.h>
#import "IPAddrEvidenceSource.h"
#import "IPv6RuleType.h"


@interface CachedIPv6RuleParams : NSObject
@end

@implementation CachedIPv6RuleParams {
@public
    struct in6_addr addr;
    unsigned int prefixLen;
    int index;
}
@end


@implementation IPv6RuleType {
    // For custom panel
    IBOutlet NSComboBox *addressComboBox;
    IBOutlet NSTextField *prefixLengthTextField;
}

+ (NSString *)panelNibName {
    return @"IPv6AddrRule";
}

- (NSString *)name {
    return @"IPv6";
}

- (BOOL)parseParamsOf:(NSMutableDictionary *)rule toNetworkAddress:(struct in6_addr *)address
                                                   andPrefixLength:(unsigned int *)prefixLength {
	NSString *ruleAddress = rule[@"parameter"];
    if (!ruleAddress || (inet_pton(AF_INET6, [ruleAddress UTF8String], address) != 1)) {
        return NO;	// corrupted rule
    }

    NSNumber *rulePrefixLenght = rule[@"parameter.prefixLength"];
    *prefixLength = (rulePrefixLenght) ? ([rulePrefixLenght unsignedIntValue]) : (128u);

    return YES;
}

static BOOL areEqualIPv6Subnetworks(const struct in6_addr *addr,
                                    const struct in6_addr *otherAddr,
                                    unsigned int prefixLen) {
    // bytes are in the network order (most significat come first)
    uint8_t *byte = (uint8_t *)addr, *otherByte = (uint8_t *)otherAddr;

    while (prefixLen > 8) {
        if (*byte != *otherByte) {
            return NO;
        }
        ++byte;
        ++otherByte;
        prefixLen -= 8;
    }

    static const uint8_t byteMasks[] = { 0x0, 0x80, 0xC0, 0xE0, 0xF0, 0xF8, 0xFC, 0xFE, 0xFF };

    uint8_t mask = (prefixLen > 0) ? (byteMasks[prefixLen]) : (0x0);
    return ((*byte & mask) == (*otherByte & mask));
}

- (BOOL)doParamsMatch:(CachedIPv6RuleParams *)params {
    NSArray *addresses = ((IPAddrEvidenceSource *) self.evidenceSource).packedIPv6Addresses;
    const NSUInteger index = (NSUInteger) params->index;
    if (index >= [addresses count]) {
        return NO;
    }

    PackedIPv6Address *ipv6 = (PackedIPv6Address *) addresses[index];
    return areEqualIPv6Subnetworks([ipv6 inAddr], &(params->addr), params->prefixLen);
}

- (BOOL)doesRuleMatch:(NSMutableDictionary *)rule {
    CachedIPv6RuleParams *cachedParams = rule[@"cachedParams"];
    if (cachedParams) {
        if ((cachedParams->index >= 0) && [self doParamsMatch:cachedParams]) {
            return YES;
        }
    } else {
        cachedParams = [[CachedIPv6RuleParams alloc] init];
        if (![self parseParamsOf:rule toNetworkAddress:&(cachedParams->addr)
                                       andPrefixLength:&(cachedParams->prefixLen)]) {
            return NO; // corrupted rule
        }
        rule[@"cachedParams"] = cachedParams;
    }

    cachedParams->index = -1;

    NSArray *addresses = ((IPAddrEvidenceSource *) self.evidenceSource).packedIPv6Addresses;
    [addresses enumerateObjectsUsingBlock:^(PackedIPv6Address *packedIPAddr, NSUInteger idx, BOOL *stop) {
        if (areEqualIPv6Subnetworks([packedIPAddr inAddr], &(cachedParams->addr), cachedParams->prefixLen)) {
            cachedParams->index = (int) idx; // for quick matching on future calls
            *stop = YES;
        }
    }];

    return (cachedParams->index >= 0);
}

static BOOL isValidIPv6Address(NSString *value) {
    struct in6_addr ipv6;
    return (inet_pton(AF_INET6, [value UTF8String], &ipv6) == 1);
}

- (BOOL)validatePanelParams {
    NSString *addr = [addressComboBox stringValue];
    addr = [addr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [addressComboBox setStringValue:addr];

    NSString *lenStr = [prefixLengthTextField stringValue];
    lenStr = [lenStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [prefixLengthTextField setStringValue:lenStr];

    if (![addr length]) {
        [[self class] alertOnInvalidParamValueWith:NSLocalizedString(@"IP address cannot be empty", @"")];
        return NO;
    }
    if (!isValidIPv6Address(addr)) {
        [[self class] alertOnInvalidParamValueWith:NSLocalizedString(@"Not a valid IPv6 address", @"")];
        return NO;
    }

    if (![lenStr length]) {
        [[self class] alertOnInvalidParamValueWith:NSLocalizedString(@"Prefix length cannot be empty", @"")];
        return NO;
    }

    int len = 0;
    NSScanner *scanner = [NSScanner scannerWithString:lenStr];
    if (![scanner scanInt:&len] || ![scanner isAtEnd]) {
        [[self class] alertOnInvalidParamValueWith:NSLocalizedString(@"Not a valid value for prefix length", @"")];
        return NO;
    }

    if ((len < 1) || (128 < len)) {
        [[self class] alertOnInvalidParamValueWith:
                NSLocalizedString(@"Prefix length of IPv6 address must be between 1 and 128.", @"")];
        return NO;
    }
    
    return YES;
}

- (void)readFromPanelInto:(NSMutableDictionary *)rule {
    [super readFromPanelInto:rule];
    rule[@"parameter"] = [addressComboBox stringValue];
    rule[@"parameter.prefixLength"] = [prefixLengthTextField stringValue];
}

- (NSString *)getDefaultDescription:(NSDictionary *)rule {
    return [NSString stringWithFormat:@"%@/%@", [addressComboBox stringValue], [prefixLengthTextField stringValue]];
}

- (void)writeToPanel:(NSDictionary *)rule {
    [super writeToPanel:rule];

    // Set IP address
	NSArray *currentAddresses = ((IPAddrEvidenceSource *) self.evidenceSource).stringIPv6Addresses;
	[addressComboBox removeAllItems];
    
	NSString *ipAddress = rule[@"parameter"];
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

    NSString *len = rule[@"parameter.prefixLength"];
    [prefixLengthTextField setStringValue:((len) ? (len) : (NSLocalizedString(@"128", @"128")))];
}

@end
