//
//  IPAddrEvidenceSource.h
//  ControlPlane
//
//  Created by Vladimir Beloborodov on 18 Apr 2013.
//

#import "MultiRuleEvidenceSource.h"

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
