//
//  DNSEvidenceSource.m
//  ControlPlane
//
//  Created by Vladimir Beloborodov on 08/03/2013.
//

#import <SystemConfiguration/SystemConfiguration.h>
#import "DNSEvidenceSource.h"
#import "SearchDomainRuleType.h"
#import "ServerAddressRuleType.h"


@interface DNSEvidenceSource ()

@property (atomic, retain, readwrite) NSSet *searchDomains;
@property (atomic, retain, readwrite) NSSet *dnsServers;

- (void)doFullUpdate;
- (void)doStop;

@end


#pragma mark C callbacks

static void dnsChange(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {
#ifdef DEBUG_MODE
	NSLog(@"dnsChange called with changedKeys:\n%@", changedKeys);
#endif
    [(DNSEvidenceSource *) info doFullUpdate];
}

static BOOL addDNSSearchDomainsToSet(CFDictionaryRef keys, NSString *dnsKey, NSMutableSet *domains) {
    const void *dnsParams;
    if (!CFDictionaryGetValueIfPresent(keys, (CFStringRef) dnsKey, &dnsParams)) {
        return NO;
    }
    
    BOOL isAnyValueAdded = NO;
    
    const void *value;
    if (CFDictionaryGetValueIfPresent((CFDictionaryRef) dnsParams, kSCPropNetDNSDomainName, &value)) {
        [domains addObject:(NSString *) value];
        isAnyValueAdded = YES;
    }
    if (CFDictionaryGetValueIfPresent((CFDictionaryRef) dnsParams, kSCPropNetDNSSearchDomains, &value)) {
        [domains addObjectsFromArray:(NSArray *) value];
        isAnyValueAdded = YES;
    }
    
    return isAnyValueAdded;
}

static BOOL addDNSServersToSet(CFDictionaryRef keys, NSString *dnsKey, NSMutableSet *servers) {
    const void *dnsParams;
    if (!CFDictionaryGetValueIfPresent(keys, (CFStringRef) dnsKey, &dnsParams)) {
        return NO;
    }
    
    const void *value;
    if (CFDictionaryGetValueIfPresent((CFDictionaryRef) dnsParams, kSCPropNetDNSServerAddresses, &value)) {
        [servers addObjectsFromArray:(NSArray *) value];
        return YES;
    }
    
    return NO;
}


@implementation DNSEvidenceSource {
    // for SystemConfiguration asynchronous notifications
    SCDynamicStoreRef store;
    dispatch_queue_t queue;
}

@synthesize searchDomains = _searchDomains;
@synthesize dnsServers = _dnsServers;

- (id)init {
    self = [super initWithRules:@[ [SearchDomainRuleType class], [ServerAddressRuleType class] ]];
    if (!self) {
        return nil;
    }

    _searchDomains = [NSSet new];
    _dnsServers = [NSSet new];

	return self;
}

- (void)dealloc {
	[_searchDomains release];
    [_dnsServers release];

	[super dealloc];
}


typedef struct {
    NSSet *servers;
    NSSet *domains;
} EnumeratedParams;

+ (EnumeratedParams)enumerate {
	NSMutableSet *servers = [NSMutableSet set], *domains = [NSMutableSet set];

	SCDynamicStoreContext ctxt = {0, self, NULL, NULL, NULL};
	SCDynamicStoreRef tmpStore = SCDynamicStoreCreate(NULL, CFSTR("ControlPlane"), NULL, &ctxt);
    if (!tmpStore) {
        return (EnumeratedParams) {servers, domains};
    }

    NSArray *dnsKeyPatterns = @[ @"Setup:/Network/Service/[^/]+/DNS", @"State:/Network/Service/[^/]+/DNS" ];
    CFDictionaryRef dict = SCDynamicStoreCopyMultiple(tmpStore, NULL, (CFArrayRef) dnsKeyPatterns);
    CFRelease(tmpStore);

    if (!dict) {
        return (EnumeratedParams) {servers, domains};
    }

    @autoreleasepool {
        NSMutableSet *servicesWithDNS = [NSMutableSet setWithCapacity:[(NSDictionary *) dict count]];
        // get all unique keys after stripped 'Setup:/Network/Service/' and 'State:/Network/Service/' prefixes
        for (NSString *key in (NSDictionary *) dict) {
            [servicesWithDNS addObject:[key substringFromIndex:23u]];
        }

        for (NSString *serviceDNSName in servicesWithDNS) {
            NSString *setupKey = [@"Setup:/Network/Service/" stringByAppendingString:serviceDNSName];
            NSString *stateKey = [@"State:/Network/Service/" stringByAppendingString:serviceDNSName];

            if (!addDNSServersToSet(dict, setupKey, servers)) {
                addDNSServersToSet(dict, stateKey, servers);
            }

            if (!addDNSSearchDomainsToSet(dict, setupKey, domains)) {
                addDNSSearchDomainsToSet(dict, stateKey, domains);
            }
        }
    }

    CFRelease(dict);

	return (EnumeratedParams) {servers, domains};
}

- (void)doFullUpdate {
	@autoreleasepool {
        EnumeratedParams params = [[self class] enumerate];
        
        self.searchDomains = (NSSet *) params.domains;
        self.dnsServers = (NSSet *) params.servers;
        [self setDataCollected:(([params.servers count] > 0) || ([params.domains count] > 0))];

        //[[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
    }
}

- (void)start {
	if (running) {
		return;
    }

	// Register for asynchronous notifications
	SCDynamicStoreContext ctxt = {0, self, NULL, NULL, NULL};
	store = SCDynamicStoreCreate(NULL, CFSTR("ControlPlane"), dnsChange, &ctxt);
    if (!store) {
        [self doStop];
        return;
    }

    queue = dispatch_queue_create("ControlPlane.DNS", DISPATCH_QUEUE_SERIAL);
    if (!SCDynamicStoreSetDispatchQueue(store, queue)) {
        [self doStop];
        return;
    }

    NSArray *dnsKeyPatterns = @[ @"Setup:/Network/Service/[^/]+/DNS", @"State:/Network/Service/[^/]+/DNS" ];
	if (!SCDynamicStoreSetNotificationKeys(store, NULL, (CFArrayRef) dnsKeyPatterns)) {
        [self doStop];
        return;
    }

    dispatch_async(queue, ^{
        [self doFullUpdate];
    });

	running = YES;
}

- (void)stop {
	if (running) {
        [self doStop];
    }
}

- (void)doStop {
    if (store) {
        SCDynamicStoreSetDispatchQueue(store, NULL);
        CFRelease(store);
        store = NULL;
    }

    if (queue) {
        dispatch_async(queue, ^{
            self.searchDomains = [NSSet set];
            self.dnsServers = [NSSet set];
            [self setDataCollected:NO];
        });
        dispatch_release(queue);
        queue = NULL;
    }

	running = NO;
}

- (NSString *)name {
	return @"DNS";
}

- (NSString *)friendlyName {
    return NSLocalizedString(@"DNS Parameters", @"");
}

@end
