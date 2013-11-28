//
//  ServerAddressRuleType.m
//  ControlPlane
//
//  Created by VladimirTechMan on 03/03/2013.
//
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import <arpa/inet.h>
#import "DNSEvidenceSource.h"
#import "ServerAddressRuleType.h"


@implementation ServerAddressRuleType {
    // For custom panel
    IBOutlet NSComboBox *addressComboBox;
}

+ (NSString *)panelNibName {
    return @"ServerAddressRule";
}

- (NSString *)name {
    return @"DNS Server IP Address";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
    NSString *serverAddress = rule[@"parameter"];
	if (serverAddress) {
        return [((DNSEvidenceSource *) self.evidenceSource).dnsServers containsObject:serverAddress];
    }

    return NO;	// corrupted rule
}

static BOOL isValidIPAddress(NSString *value) {
    const char *utf8 = [value UTF8String];
    
    struct in_addr ipv4;
    if (inet_pton(AF_INET, utf8, &ipv4) == 1) {
        return YES;
    }
    
    struct in6_addr ipv6;
    return (inet_pton(AF_INET6, utf8, &ipv6) == 1);
}

- (BOOL)validatePanelParams {
    NSString *addr = [addressComboBox stringValue];
    addr = [addr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [addressComboBox setStringValue:addr];

    if (![addr length]) {
        [[self class] alertOnInvalidParamValueWith:NSLocalizedString(@"IP address cannot be empty", @"")];
        return NO;
    }
    if (!isValidIPAddress(addr)) {
        [[self class] alertOnInvalidParamValueWith:NSLocalizedString(@"Not a valid IPv4 or IPv6 address", @"")];
        return NO;
    }
    return YES;
}

- (void)readFromPanelInto:(NSMutableDictionary *)rule {
    [super readFromPanelInto:rule];
    rule[@"parameter"] = [addressComboBox stringValue];
}

- (NSString *)getDefaultDescription:(NSDictionary *)rule {
    return [addressComboBox stringValue];
}

- (void)writeToPanel:(NSDictionary *)rule {
    [super writeToPanel:rule];
	[addressComboBox removeAllItems];

	NSArray *currentServers = [((DNSEvidenceSource *) self.evidenceSource).dnsServers allObjects];
    if (currentServers) {
        [addressComboBox addItemsWithObjectValues:currentServers];
    }

	NSString *serverAddress = rule[@"parameter"];
	if (serverAddress) {
        if (![currentServers containsObject:serverAddress]) {
            [addressComboBox addItemWithObjectValue:serverAddress];
        }
        [addressComboBox selectItemWithObjectValue:serverAddress];
    } else {
		serverAddress = ([currentServers count]) ? (currentServers[0]) : (@"");
    }

    [addressComboBox setStringValue:serverAddress];
}

@end
