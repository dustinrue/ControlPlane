//
//  IPAddrEvidenceSource.m
//  ControlPlane
//
//  Created by Vladimir Beloborodov on 18 Apr 2013.
//

#import <arpa/inet.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import "IPAddrEvidenceSource.h"
#import "IPv4RuleType.h"
#import "IPv6RuleType.h"


static char * const queueIsStopped = "queueIsStopped";


@interface IPAddrEvidenceSource ()

@property (atomic, retain, readwrite) NSArray *stringIPv4Addresses;
@property (atomic, retain, readwrite) NSArray *packedIPv4Addresses;

@property (atomic, retain, readwrite) NSArray *stringIPv6Addresses;
@property (atomic, retain, readwrite) NSArray *packedIPv6Addresses;

- (void)enumerate;

@end


#pragma mark C callbacks

static void ipAddrChange(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {
    if (dispatch_get_specific(queueIsStopped) != queueIsStopped) {
        @autoreleasepool {
#ifdef DEBUG_MODE
            NSLog(@"ipAddrChange called with changedKeys:\n%@", changedKeys);
#endif
            [(IPAddrEvidenceSource *) info enumerate];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
        }
    }
}


@implementation IPAddrEvidenceSource {
    // for SystemConfiguration asynchronous notifications
    SCDynamicStoreRef store;
    dispatch_queue_t serialQueue;
}

@synthesize stringIPv4Addresses = _stringIPv4Addresses;
@synthesize packedIPv4Addresses = _packedIPv4Addresses;

@synthesize stringIPv6Addresses = _stringIPv6Addresses;
@synthesize packedIPv6Addresses = _packedIPv6Addresses;

- (id)init {
    self = [super initWithRules:@[ [IPv4RuleType class], [IPv6RuleType class] ]];
    if (!self) {
        return nil;
    }

	return self;
}

- (void)dealloc {
    [self doStop];

    [_stringIPv4Addresses release];
    [_packedIPv4Addresses release];
    
    [_stringIPv6Addresses release];
    [_packedIPv6Addresses release];
    
	[super dealloc];
}

- (void)removeAllDataCollected {
    self.stringIPv4Addresses = nil;
    self.packedIPv4Addresses = nil;
    self.stringIPv6Addresses = nil;
    self.packedIPv6Addresses = nil;
    [self setDataCollected:NO];
}

static BOOL isAllowedIPv4Address(struct in_addr *ipv4) {
    in_addr_t addr = ntohl(ipv4->s_addr);
    if (IN_LOOPBACK(addr) || IN_LINKLOCAL(addr) || IN_MULTICAST(addr)) {
        return NO;
    }
    return YES;
}

static BOOL isAllowedIPv6Address(struct in6_addr *ipv6) {
    if (IN6_IS_ADDR_LOOPBACK(ipv6) || IN6_IS_ADDR_LINKLOCAL(ipv6) || IN6_IS_ADDR_MULTICAST(ipv6)) {
        return NO;
    }
    return YES;
}

- (void)enumerateIPv4Addresses:(NSArray *)addresses
                    usingBlock:(void (^)(NSString *strIPAddr, struct in_addr *ipAddr))block {
    for (NSString *addr in addresses) {
        struct in_addr ipv4;
        if ((inet_pton(AF_INET, [addr UTF8String], &ipv4) == 1) && isAllowedIPv4Address(&ipv4)) {
            block(addr, &ipv4);
        }
    }
}

- (void)enumerateIPv6Addresses:(NSArray *)addresses
                    usingBlock:(void (^)(NSString *strIPAddr, struct in6_addr *ipAddr))block {
    for (NSString *addr in addresses) {
        struct in6_addr ipv6;
        if ((inet_pton(AF_INET6, [addr UTF8String], &ipv6) == 1) && isAllowedIPv6Address(&ipv6)) {
            block(addr, &ipv6);
        }
    }
}

static NSComparator descendingSorter = ^NSComparisonResult(id obj1, id obj2) {
    return [(NSString * )obj2 compare:obj1]; // descending
};

- (void)enumerate {
    NSArray *ipKeyPatterns = @[ @"State:/Network/Interface/[^/]+/IPv." ];
    NSDictionary *dict = (NSDictionary *) SCDynamicStoreCopyMultiple(store, NULL, (CFArrayRef) ipKeyPatterns);
    if (!dict) {
        [self removeAllDataCollected];
        return;
    }

    NSMutableArray *stringIPv4Addresses = [NSMutableArray array], *packedIPv4Addresses = [NSMutableArray array];
    NSMutableArray *stringIPv6Addresses = [NSMutableArray array], *packedIPv6Addresses = [NSMutableArray array];

    [dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *ipParams, BOOL *stop) {
        NSArray *addresses = ipParams[@"Addresses"];

        if ([key hasSuffix:@"4"]) { // IPv4
            [self enumerateIPv4Addresses:addresses usingBlock:^(NSString *strIPAddr, struct in_addr *ipAddr) {
                NSValue *packedIPAddr = [NSValue valueWithBytes:ipAddr objCType:@encode(struct in_addr)];
                [stringIPv4Addresses addObject:strIPAddr];
                [packedIPv4Addresses addObject:packedIPAddr];
            }];
        } else { // IPv6
            [self enumerateIPv6Addresses:addresses usingBlock:^(NSString *strIPAddr, struct in6_addr *ipAddr) {
                NSValue *packedIPAddr = [NSValue valueWithBytes:ipAddr objCType:@encode(struct in6_addr)];
                [stringIPv6Addresses addObject:strIPAddr];
                [packedIPv6Addresses addObject:packedIPAddr];
            }];
        }
    }];

    CFRelease((CFDictionaryRef) dict);

    [stringIPv4Addresses sortUsingComparator:descendingSorter];
    [stringIPv6Addresses sortUsingComparator:descendingSorter];
    
    self.stringIPv4Addresses = stringIPv4Addresses;
    self.packedIPv4Addresses = packedIPv4Addresses;
    self.stringIPv6Addresses = stringIPv6Addresses;
    self.packedIPv6Addresses = packedIPv6Addresses;
    [self setDataCollected:(([packedIPv4Addresses count] > 0) || ([packedIPv6Addresses count] > 0))];
}

- (void)start {
	if (running) {
		return;
    }

    serialQueue = dispatch_queue_create("com.dustinrue.ControlPlane.IPAddrEvidenceSource",
                                        DISPATCH_QUEUE_SERIAL);
    if (!serialQueue) {
        [self doStop];
        return;
    }

	// Register for asynchronous notifications
	SCDynamicStoreContext ctxt = {0, self, NULL, NULL, NULL}; // {version, info, retain, release, copyDescription}
	store = SCDynamicStoreCreate(NULL, CFSTR("ControlPlane"), ipAddrChange, &ctxt);
    if (!store) {
        [self doStop];
        return;
    }
    
    if (!SCDynamicStoreSetDispatchQueue(store, serialQueue)) {
        [self doStop];
        return;
    }

    NSArray *ipKeyPatterns = @[ @"State:/Network/Interface/[^/]+/IPv." ];
	if (!SCDynamicStoreSetNotificationKeys(store, NULL, (CFArrayRef) ipKeyPatterns)) {
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
	return @"IPAddr";
}

- (NSString *)friendlyName {
    return NSLocalizedString(@"Assigned IP Address", @"");
}

@end
