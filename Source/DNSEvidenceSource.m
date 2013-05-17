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
    [[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
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


typedef struct {
    NSSet *servers;
    NSSet *domains;
} EnumeratedDNSParams;

- (EnumeratedDNSParams)enumerate {
    NSArray *dnsKeyPatterns = @[ @"Setup:/Network/Service/[^/]+/DNS", @"State:/Network/Service/[^/]+/DNS" ];
    CFDictionaryRef dict = SCDynamicStoreCopyMultiple(store, NULL, (CFArrayRef) dnsKeyPatterns);
    if (!dict) {
        return (EnumeratedDNSParams) {nil, nil};
    }

	NSMutableSet *servers = [NSMutableSet set], *domains = [NSMutableSet set];
    NSMutableSet *servicesWithDNS = [NSMutableSet setWithCapacity:[(NSDictionary *) dict count]];
    
    // get all unique keys after stripping prefixes 'Setup:/Network/Service/' and 'State:/Network/Service/'
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

    CFRelease(dict);

	return (EnumeratedDNSParams) {servers, domains};
}

static char * const strQueueIsRunning = "queueIsRunning";

- (void)doFullUpdate {
    if (dispatch_get_specific(strQueueIsRunning)) {
        @autoreleasepool {
            EnumeratedDNSParams params = [self enumerate];
            
            self.searchDomains = (NSSet *) params.domains;
            self.dnsServers = (NSSet *) params.servers;
            [self setDataCollected:(([params.servers count] > 0) || ([params.domains count] > 0))];
        }
    }
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
    
    dispatch_queue_set_specific(serialQueue, strQueueIsRunning, strQueueIsRunning, NULL);
    
    if (!SCDynamicStoreSetDispatchQueue(store, serialQueue)) {
        [self doStop];
        return;
    }

    NSArray *dnsKeyPatterns = @[ @"Setup:/Network/Service/[^/]+/DNS", @"State:/Network/Service/[^/]+/DNS" ];
	if (!SCDynamicStoreSetNotificationKeys(store, NULL, (CFArrayRef) dnsKeyPatterns)) {
        [self doStop];
        return;
    }

    dispatch_async(serialQueue, ^{
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
    if (serialQueue) {
        if (store) {
            dispatch_suspend(serialQueue);

            SCDynamicStoreSetDispatchQueue(store, NULL);

            dispatch_queue_set_specific(serialQueue, strQueueIsRunning, NULL, NULL);
            dispatch_resume(serialQueue);
        }

        dispatch_release(serialQueue);
        serialQueue = NULL;
    }

    if (store) {
        CFRelease(store);
        store = NULL;
    }

    self.searchDomains = nil;
    self.dnsServers = nil;
    [self setDataCollected:NO];

	running = NO;
}

- (NSString *)name {
	return @"DNS";
}

- (NSString *)friendlyName {
    return NSLocalizedString(@"DNS Parameters", @"");
}

@end
