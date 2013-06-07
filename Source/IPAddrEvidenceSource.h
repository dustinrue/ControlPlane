//
//  IPAddrEvidenceSource.h
//  ControlPlane
//
//  Created by Vladimir Beloborodov on 18 Apr 2013.
//

#import <arpa/inet.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import "MultiRuleEvidenceSource.h"

@interface PackedIPv4Address : NSObject

- (id)initWithString:(NSString *)description;
- (const struct in_addr *)inAddr;

@end

@interface PackedIPv6Address : NSObject

- (id)initWithString:(NSString *)description;
- (const struct in6_addr *)inAddr;

@end


@interface IPAddrEvidenceSource : MultiRuleEvidenceSource

@property (atomic, retain, readonly) NSArray *stringIPv4Addresses;
@property (atomic, retain, readonly) NSArray *packedIPv4Addresses;

@property (atomic, retain, readonly) NSArray *stringIPv6Addresses;
@property (atomic, retain, readonly) NSArray *packedIPv6Addresses;

- (id)init;
- (void)dealloc;

- (void)start;
- (void)stop;

- (NSString *)name;
- (NSString *)friendlyName;

@end
