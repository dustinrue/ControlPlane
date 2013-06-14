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
            [(DNSEvidenceSource *) info enumerate];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
        }
    }
}

static BOOL addDNSSearchDomainsToSet(NSDictionary *dict, NSString *dnsKey, NSMutableSet *domains) {
    NSDictionary *dnsParams = dict[dnsKey];
    if (!dnsParams) {
        return NO;
    }

    BOOL isAnyValueAdded = NO;

    NSString *domainName = dnsParams[(NSString *) kSCPropNetDNSDomainName];
    if (domainName) {
        [domains addObject:domainName];
        isAnyValueAdded = YES;
    }

    NSArray *searchDomains = dnsParams[(NSString *) kSCPropNetDNSSearchDomains];
    if (searchDomains) {
        [domains addObjectsFromArray:searchDomains];
        isAnyValueAdded = YES;
    }

    return isAnyValueAdded;
}

static BOOL addDNSServersToSet(NSDictionary *dict, NSString *dnsKey, NSMutableSet *servers) {
    NSArray *serverAddresses = dict[dnsKey][(NSString *) kSCPropNetDNSServerAddresses];
    if (serverAddresses) {
        [servers addObjectsFromArray:serverAddresses];
        return YES;
    }

    return NO;
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

	return self;
}

- (void)dealloc {
    [self doStop];

	[_searchDomains release];
    [_dnsServers release];

	[super dealloc];
}

- (NSString *) description {
    return NSLocalizedString(@"Create rules based on the assigned DNS search domain and servers.", @"");
}

- (void)removeAllDataCollected {
    self.searchDomains = nil;
    self.dnsServers = nil;
    [self setDataCollected:NO];
}

- (void)enumerate {
    NSArray *dnsKeyPatterns = @[ @"S....:/Network/Service/[^/]+/DNS" ]; // Setup or State keys
    NSDictionary *dict = (NSDictionary *) SCDynamicStoreCopyMultiple(store, NULL, (CFArrayRef) dnsKeyPatterns);
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
    [self setDataCollected:(([servers count] > 0) || ([domains count] > 0))];
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
	SCDynamicStoreContext ctxt = {0, self, NULL, NULL, NULL}; // {version, info, retain, release, copyDescription}
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
	if (!SCDynamicStoreSetNotificationKeys(store, NULL, (CFArrayRef) dnsKeyPatterns)) {
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

        dispatch_release(serialQueue);
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
