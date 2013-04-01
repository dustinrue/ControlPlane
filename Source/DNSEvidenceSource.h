//
//  DNSEvidenceSource.h
//  ControlPlane
//
//  Created by Vladimir Beloborodov on 08/03/2013.
//

#import "MultiRuleEvidenceSource.h"

@interface DNSEvidenceSource : MultiRuleEvidenceSource

@property (atomic, retain, readonly) NSSet *searchDomains;
@property (atomic, retain, readonly) NSSet *dnsServers;

- (id)init;
- (void)dealloc;

- (void)start;
- (void)stop;

- (NSString *)name;
- (NSString *)friendlyName;

@end
