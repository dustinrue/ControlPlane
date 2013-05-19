//
//  IPv6RuleType.m
//  ControlPlane
//
//  Created by VladimirTechMan on 19 Apr 2013.
//
//

#import <arpa/inet.h>
#import "IPAddrEvidenceSource.h"
#import "IPv6RuleType.h"


@implementation IPv6RuleType {
    // For custom panel
    IBOutlet NSComboBox *addressComboBox;
    IBOutlet NSTextField *prefixLengthTextField;
}

+ (NSString *)panelNibName {
    return @"IPv6AddrRule";
}

- (NSString *)name {
    return NSLocalizedString(@"IPv6", @"");
}

- (void)dealloc {
    [super dealloc];
}

- (BOOL)parseParamsOf:(NSMutableDictionary *)rule
     toNetworkAddress:(struct in6_addr *)address
      andPrefixLength:(unsigned int *)prefixLength {

    NSNumber *rulePrefixLenght = rule[@"parameter.prefixLength"];
    *prefixLength = (rulePrefixLenght) ? ([rulePrefixLenght unsignedIntValue]) : (128u);
    
    NSNumber *cachedAddress = rule[@"cachedAddress"];
    if (cachedAddress) {
        [(NSValue *) cachedAddress getValue:address];
        return YES;
    }

	NSString *ruleAddress = rule[@"parameter"];
	if (!ruleAddress) {
		return NO;	// corrupted rule
    }

    if (inet_pton(AF_INET6, [ruleAddress UTF8String], address) != 1) {
        return NO;
    }

    rule[@"cachedAddress"] = [NSValue valueWithBytes:address objCType:@encode(struct in6_addr)];

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

- (BOOL)doesAddressAtIndex:(NSUInteger)index
       matchNetworkAddress:(struct in6_addr *)address
         usingPrefixLength:(unsigned int)prefixLength {

    NSArray *addresses = ((IPAddrEvidenceSource *) self.evidenceSource).packedIPv6Addresses;
    if (index < [addresses count]) {
        struct in6_addr ipv6;
        [(NSValue *) addresses[index] getValue:&ipv6];
        return areEqualIPv6Subnetworks(address, &ipv6, prefixLength);
    }

    return NO;
}

- (BOOL)doesRuleMatch:(NSMutableDictionary *)rule {
    struct in6_addr address;
    unsigned int prefixLength;
    if (![self parseParamsOf:rule toNetworkAddress:&address andPrefixLength:&prefixLength]) {
        return NO; // corrupted rule
    }

    NSNumber *index = rule[@"cachedIndex"];
    if (index && [self doesAddressAtIndex:[index unsignedIntegerValue]
                       matchNetworkAddress:&address usingPrefixLength:prefixLength]) {
        return YES;
    }

    __block BOOL match = NO;

    NSArray *addresses = ((IPAddrEvidenceSource *) self.evidenceSource).packedIPv6Addresses;
    [addresses enumerateObjectsUsingBlock:^(NSValue *packedIPAddr, NSUInteger idx, BOOL *stop) {
        struct in6_addr ipv6;
        [packedIPAddr getValue:&ipv6];
        if (areEqualIPv6Subnetworks(&address, &ipv6, prefixLength)) {
            *stop = match = YES;
            rule[@"cachedIndex"] = @(idx); // for quick matching on future calls
        }
    }];

    return match;
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
	NSArray *currentAddresses = ((IPAddrEvidenceSource *) self.evidenceSource).stringIPv6Addresses;

    // Set IP address
	[addressComboBox removeAllItems];
    if (currentAddresses) {
        [addressComboBox addItemsWithObjectValues:currentAddresses];
    }
    
	NSString *ipAddress = rule[@"parameter"];
	if (ipAddress) {
        if (![currentAddresses containsObject:ipAddress]) {
            [addressComboBox addItemWithObjectValue:ipAddress];
        }
    } else {
		ipAddress = ([currentAddresses count]) ? (currentAddresses[0]) : (@"");
    }

    [addressComboBox setStringValue:ipAddress];

    NSString *len = rule[@"parameter.prefixLength"];
    [prefixLengthTextField setStringValue:((len) ? (len) : (@"128"))];
}

@end
