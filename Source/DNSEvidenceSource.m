//
//  DNSEvidenceSource.m
//  ControlPlane
//
//  Created by Vladimir Beloborodov on 08/03/2013.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import <SystemConfiguration/SystemConfiguration.h>
#import "DNSEvidenceSource.h"
#import "SearchDomainRuleType.h"
#import "ServerAddressRuleType.h"


static char * const queueIsStopped = "queueIsStopped";

@interface DNSEvidenceSource ()

@property (atomic, retain, readwrite) NSSet *searchDomains;
@property (atomic, retain, readwrite) NSSet *dnsServers;

- (void)enumerate;

@end


#pragma mark C callbacks

static void dnsChange(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {
    if (dispatch_get_specific(queueIsStopped) != queueIsStopped) {
        @autoreleasepool {
#ifdef DEBUG_MODE
            NSLog(@"dnsChange called with changedKeys:\n%@", changedKeys);
#endif
            [(__bridge DNSEvidenceSource *) info enumerate];
        }
    }
}

static BOOL addDNSSearchDomainsToSet(NSDictionary *dict, NSString *dnsKey, NSMutableSet *domains) {
    NSDictionary *dnsParams = dict[dnsKey];
    if ((dnsParams == nil) || ![dnsParams isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    
    NSUInteger domainsOriginalCount = [domains count];
    
    id domainName = dnsParams[(NSString *)kSCPropNetDNSDomainName];
    if ((domainName != nil) && [domainName isKindOfClass:[NSString class]]) {
        [domains addObject:domainName];
    }
    
    id searchDomains = dnsParams[(NSString *)kSCPropNetDNSSearchDomains];
    if (searchDomains != nil) {
        if ([searchDomains isKindOfClass:[NSArray class]]) {
            [searchDomains enumerateObjectsUsingBlock:^(id domain, NSUInteger idx, BOOL *stop) {
                if ([domain isKindOfClass:[NSString class]]) {
                    [domains addObject:domain];
                }
            }];
        } else if ([searchDomains isKindOfClass:[NSString class]]) {
            [domains addObject:searchDomains];
        } else {
#ifdef DEBUG_MODE
            NSLog(@"Unexpected value type of property \"%@\" for key \"%@/\". Value object: %@.",
                  (NSString *)kSCPropNetDNSSearchDomains, dnsKey, searchDomains);
#endif
        }
    }
    
    BOOL isAnyValueAdded = ([domains count] != domainsOriginalCount);
    return isAnyValueAdded;
}

static BOOL addDNSServersToSet(NSDictionary *dict, NSString *dnsKey, NSMutableSet *servers) {
    NSDictionary *dnsParams = dict[dnsKey];
    if ((dnsParams == nil) || ![dnsParams isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    
    NSUInteger serversOriginalCount = [servers count];
    
    id serverAddresses = dnsParams[(NSString *)kSCPropNetDNSServerAddresses];
    if (serverAddresses != nil) {
        if ([serverAddresses isKindOfClass:[NSArray class]]) {
            [serverAddresses enumerateObjectsUsingBlock:^(id server, NSUInteger idx, BOOL *stop) {
                if ([server isKindOfClass:[NSString class]]) {
                    [servers addObject:server];
                }
            }];
        } else if ([serverAddresses isKindOfClass:[NSString class]]) {
            [servers addObject:serverAddresses];
        } else {
#ifdef DEBUG_MODE
            NSLog(@"Unexpected value type of property \"%@\" for key \"%@/\". Value object: %@.",
                  (NSString *)kSCPropNetDNSServerAddresses, dnsKey, serverAddresses);
#endif
        }
    }
    
    BOOL isAnyValueAdded = ([servers count] != serversOriginalCount);
    return isAnyValueAdded;
}


@implementation DNSEvidenceSource {
    // for SystemConfiguration asynchronous notifications
    SCDynamicStoreRef store;
    dispatch_queue_t serialQueue;
}

@synthesize searchDomains = _searchDomains;
@synthesize dnsServers = _dnsServers;

- (id)init {
    self = [super initWithRules:@[ [SearchDomainRuleType class], [ServerAddressRuleType class] ]];
    if (!self) {
        return nil;
    }

    [self setDataCollected:YES];
    
	return self;
}

- (void)dealloc {
    [self doStop];
}

- (NSString *)description {
    return NSLocalizedString(@"Create rules based on the assigned DNS search domain and servers.", @"");
}

- (void)removeAllDataCollected {
    self.searchDomains = nil;
    self.dnsServers = nil;
}

- (void)enumerate {
    NSArray *dnsKeyPatterns = @[ @"S....:/Network/Service/[^/]+/DNS" ]; // Setup or State keys
    NSDictionary *dict = (__bridge NSDictionary *) SCDynamicStoreCopyMultiple(store, NULL,
                                                                              (__bridge CFArrayRef) dnsKeyPatterns);
    if (!dict) {
        [self removeAllDataCollected];
        return;
    }

	NSMutableSet *servers = [NSMutableSet set], *domains = [NSMutableSet set];
    NSMutableSet *servicesWithDNS = [NSMutableSet setWithCapacity:[dict count]];

    // Get all unique keys after stripping prefixes 'Setup:/Network/Service/' and 'State:/Network/Service/'.
    // This implementation uses the fact that both prefixes have the same length of 23 characters.
    for (NSString *key in dict) {
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

    CFRelease((CFDictionaryRef) dict);

    self.searchDomains = (NSSet *) domains;
    self.dnsServers = (NSSet *) servers;
}

- (void)start {
	if (running) {
		return;
    }

    serialQueue = dispatch_queue_create("com.dustinrue.ControlPlane.DNSEvidenceSource", DISPATCH_QUEUE_SERIAL);
    if (!serialQueue) {
        [self doStop];
        return;
    }

	// Register for asynchronous notifications
    // {version, info, retain, release, copyDescription}
	SCDynamicStoreContext ctxt = {0, (__bridge void *)(self), NULL, NULL, NULL};
	store = SCDynamicStoreCreate(NULL, CFSTR("ControlPlane"), dnsChange, &ctxt);
    if (!store) {
        [self doStop];
        return;
    }
    
    if (!SCDynamicStoreSetDispatchQueue(store, serialQueue)) {
        [self doStop];
        return;
    }

    NSArray *dnsKeyPatterns = @[ @"S....:/Network/Service/[^/]+/DNS" ]; // Setup or State keys
	if (!SCDynamicStoreSetNotificationKeys(store, NULL, (__bridge CFArrayRef) dnsKeyPatterns)) {
        [self doStop];
        return;
    }

    dispatch_async(serialQueue, ^{
        if (dispatch_get_specific(queueIsStopped) != queueIsStopped) {
            @autoreleasepool {
                [self enumerate];
            }
        }
    });

	running = YES;
}

- (void)stop {
	if (running) {
        [self doStop];
    }
}

- (void)doStop {
    if (serialQueue) {
        if (store) {
            dispatch_suspend(serialQueue);

            SCDynamicStoreSetDispatchQueue(store, NULL);

            dispatch_queue_set_specific(serialQueue, queueIsStopped, queueIsStopped, NULL);
            dispatch_resume(serialQueue);
        }

        serialQueue = NULL;
    }

    if (store) {
        CFRelease(store);
        store = NULL;
    }

    [self removeAllDataCollected];

	running = NO;
}

- (NSString *)name {
	return @"DNS";
}

- (NSString *)friendlyName {
    return NSLocalizedString(@"DNS Parameters", @"");
}

@end
