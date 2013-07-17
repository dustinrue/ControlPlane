//
//  NetworkLinkEvidenceSource.m
//  ControlPlane
//
//  Created by Mark Wallis on 25/07/07.
//  Tweaks by David Symonds on 25/07/07.
//  Changed by Ingvar Nedrebo 27/03/13
//

#import <SystemConfiguration/SystemConfiguration.h>
#import "NetworkLinkEvidenceSource.h"


static char * const queueIsStopped = "queueIsStopped";

#pragma mark C callbacks

static void linkChange(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {
    if (dispatch_get_specific(queueIsStopped) != queueIsStopped) {
        @autoreleasepool {
#ifdef DEBUG_MODE
            NSLog(@"linkChange called with changedKeys:\n%@", changedKeys);
#endif
            [(NetworkLinkEvidenceSource *) info doFullUpdate:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
        }
    }
}

@implementation NetworkLinkEvidenceSource {
	NSLock *lock;
	NSMutableArray *interfaces;
    BOOL didSleep;

    // To get network services
    SCPreferencesRef prefs;
	// For SystemConfiguration asynchronous notifications
	SCDynamicStoreRef store;
    dispatch_queue_t serialQueue;
}


- (id)init {
	if (!(self = [super init])) {
		return nil;
    }

	lock = [[NSLock alloc] init];
	interfaces = [[NSMutableArray alloc] init];
    didSleep = NO;

	return self;
}

- (void)dealloc {
    [self doStop];
    
	[lock release];
	[interfaces release];

	[super dealloc];
}


- (NSString *)description {
    return NSLocalizedString(@"Create rules based on what network links are active on your Mac.  This can include LAN, WiFi or other network links available on your Mac.", @"");
}

- (NSArray *)enumerate {
    NSArray *services = [(NSArray *)SCNetworkServiceCopyAll(prefs) autorelease];

    // For some connections, we get several Services with different ID
    // but same name (e.g. 'Ethernet'), presumably because they have
    // different parameters. Enumerate by name here, because we're only
    // interested in whether an interface is active, and not which specific
    // Service caused it.

    NSMutableDictionary *serviceState = [NSMutableDictionary dictionary];
	NSEnumerator *e = [services objectEnumerator];
    SCNetworkServiceRef service;
    while (service = (SCNetworkServiceRef) [e nextObject]) {
		NSString *serviceName = (NSString *) SCNetworkServiceGetName(service);
        if ([serviceState[serviceName] boolValue]) {
            continue;
        }

		NSString *serviceID = (NSString *) SCNetworkServiceGetServiceID(service);
        BOOL isActive = [self isProtocol:@"IPv4" activeForService:serviceID];
        if (!isActive) {
            isActive = [self isProtocol:@"IPv6" activeForService:serviceID];
        }
        serviceState[serviceName] = @(isActive);
    }

	NSMutableArray *subset = [NSMutableArray array];
    for (NSString *name in serviceState) {
        NSString *opt = [serviceState[name] boolValue] ? @"+" : @"-";
        [subset addObject:[opt stringByAppendingString:name]];
    }
	return subset;
}

- (void)doFullUpdate:(id)sender {
    NSArray *inters = [self enumerate];
    
    [lock lock];
    [interfaces setArray:inters];
    [self setDataCollected:[interfaces count] > 0];
    [lock unlock];
}

- (void) goingToSleep:(id)arg {
    [super goingToSleep:arg];
    didSleep = YES;
}

- (void)start {
	if (running) {
		return;
    }

    serialQueue = dispatch_queue_create("com.dustinrue.ControlPlane.NetworkLink", DISPATCH_QUEUE_SERIAL);
    if (!serialQueue) {
        [self doStop];
        return;
    }

	// Register for asynchronous notifications
	SCDynamicStoreContext ctxt = {0, self, NULL, NULL, NULL}; // {version, info, retain, release, copyDescription}
	store = SCDynamicStoreCreate(NULL, CFSTR("ControlPlane"), linkChange, &ctxt);
    if (!store) {
        [self doStop];
        return;
    }
    
    if (!SCDynamicStoreSetDispatchQueue(store, serialQueue)) {
        [self doStop];
        return;
    }
    
    // Notify on IPv4/IPv6 updates on all services
    NSArray *patterns = @[ @"State:/Network/Service/[^/]+/IPv." ];
	if (!SCDynamicStoreSetNotificationKeys(store, NULL, (CFArrayRef) patterns)) {
        [self doStop];
        return;
    }

    // For retrieving network services later
    prefs = SCPreferencesCreate(NULL, CFSTR("ControlPlane"), NULL);
    if (!prefs) {
        [self doStop];
        return;
    }

    // Delay initial scan if we're waking from sleep, otherwise we'll get false
    // negatives for interfaces that takes time to become active (e.g. slow DHCP)
    NSTimeInterval delay = (didSleep) ? (15.0 * NSEC_PER_SEC) : (0.0);
    dispatch_time_t scanTime = dispatch_time(DISPATCH_TIME_NOW, delay);
    dispatch_after(scanTime, serialQueue, ^{
        if (dispatch_get_specific(queueIsStopped) != queueIsStopped) {
            @autoreleasepool {
                [self doFullUpdate:nil];
            }
        }
    });

    didSleep = NO;
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

    if (prefs) {
        CFRelease(prefs);
        prefs = NULL;
    }

	[lock lock];
	[interfaces removeAllObjects];
	[self setDataCollected:NO];
	[lock unlock];

	running = NO;
}

- (NSString *)name {
	return @"NetworkLink";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
	NSString *service = rule[@"parameter"];

	[lock lock];
    BOOL match = [interfaces containsObject:service];
	[lock unlock];

	return match;
}

- (NSString *)getSuggestionLeadText:(NSString *)type {
	return NSLocalizedString(@"Network link on interface", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions {
	NSMutableArray *arr = [NSMutableArray array];
	NSArray *all = [(NSArray *)SCNetworkServiceCopyAll(prefs) autorelease];

    // See comments in -enumerate:
    NSMutableSet *alreadySeen = [NSMutableSet set];

	NSEnumerator *en = [all objectEnumerator];
    SCNetworkServiceRef service;
	while ((service = (SCNetworkServiceRef) [en nextObject])) {
		NSString *name = (NSString *) SCNetworkServiceGetName(service);
        if ([alreadySeen containsObject:name]) {
            continue;
        }

		NSString *activeDesc = [NSString stringWithFormat:
                                NSLocalizedString(@"%@ link active", @"In NetworkLinkEvidenceSource"), name];
		NSString *inactiveDesc = [NSString stringWithFormat:
                                  NSLocalizedString(@"%@ link inactive", @"In NetworkLinkEvidenceSource"), name];
		NSString *activeParam = [@"+" stringByAppendingString:name];
		NSString *inactiveParam = [@"-" stringByAppendingString:name];

		[arr addObject:@{ @"type": @"NetworkLink", @"parameter": activeParam, @"description": activeDesc }];
		[arr addObject:@{ @"type": @"NetworkLink", @"parameter": inactiveParam, @"description": inactiveDesc }];

        [alreadySeen addObject:name];
	}

    [arr sortUsingDescriptors:@[ [NSSortDescriptor sortDescriptorWithKey:@"description" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)] ]];
	return arr;
}

- (NSString *)friendlyName {
    return NSLocalizedString(@"Active Network Adapter", @"");
}

// A service is considered active if IPv4 or IPv6 device name has been assigned
- (BOOL)isProtocol:(NSString *)protocol activeForService:(NSString *)serviceID {
    BOOL isActive = NO;
    NSString *key = [NSString stringWithFormat:@"State:/Network/Service/%@/%@", serviceID, protocol];
    CFDictionaryRef protoDict = SCDynamicStoreCopyValue(store, (CFStringRef)key);
    if (protoDict) {
        isActive = CFDictionaryContainsKey(protoDict, CFSTR("InterfaceName"));
        CFRelease(protoDict);
    }
    return isActive;
}

@end
