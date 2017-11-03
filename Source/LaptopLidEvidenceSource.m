//
//  LaptopLidEvidenceSource.m
//  ControlPlane
//
//  Created by Vladimir Beloborodov on July 15, 2013.
//  Modified by Vladimir Beloborodov on August 05, 2013.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import <IOKit/IOKitLib.h>
#import <IOKit/pwr_mgt/IOPM.h>
#import <mach/mach.h>
#import "DSLogger.h"
#import "LaptopLidEvidenceSource.h"

typedef NS_ENUM(int, LaptopLidStateType) {
    LaptopLidStateIsUnavailable = -1,
    LaptopLidIsOpen = 0,
    LaptopLidIsClosed = 1
};

static void onPMrootDomainChange(void *refcon, io_service_t service, uint32_t messageType, void *messageArgument) {
    if (messageType == kIOPMMessageClamshellStateChange) {
        const int isClamshellClosed = ((int) messageArgument & kClamshellStateBit);
        *((LaptopLidStateType *) refcon) = (isClamshellClosed) ? (LaptopLidIsClosed) : (LaptopLidIsOpen);
#ifdef DEBUG_MODE
        DSLog(@"Laptop lid state has changed to %@.", (isClamshellClosed) ? (@"closed") : (@"open"));
#endif
    }
}

@interface LaptopLidEvidenceSource () {
    LaptopLidStateType laptopLidState;

    dispatch_queue_t serialQueue;
    IONotificationPortRef notifyPort;
    io_object_t notification;
}

@end

@implementation LaptopLidEvidenceSource

+ (LaptopLidStateType)isLidClosed {
    LaptopLidStateType isClosed = LaptopLidStateIsUnavailable;

    io_registry_entry_t rootDomain = IORegistryEntryFromPath(kIOMasterPortDefault,
                                                             kIOPowerPlane ":/IOPowerConnection/IOPMrootDomain");

    if (rootDomain != MACH_PORT_NULL) {
        CFBooleanRef state = (CFBooleanRef) IORegistryEntryCreateCFProperty(rootDomain, CFSTR(kAppleClamshellStateKey),
                                                                            kCFAllocatorDefault, 0);
        if (state != NULL) {
            isClosed = (LaptopLidStateType) CFBooleanGetValue(state);
            CFRelease(state);
        }
    }

    IOObjectRelease(rootDomain);

#ifdef DEBUG_MODE
    switch (isClosed) {
        case LaptopLidStateIsUnavailable:
            DSLog(@"Laptop lid state is unavailable: Assuming this system does not have a lid (clamshell).");
            break;
            
        case LaptopLidIsOpen:
            DSLog(@"Laptop lid is opened.");
            break;
            
        case LaptopLidIsClosed:
            DSLog(@"Laptop lid is closed.");
            break;
    }
#endif

    return isClosed;
}

+ (BOOL)isEvidenceSourceApplicableToSystem {
    return ([LaptopLidEvidenceSource isLidClosed] != LaptopLidStateIsUnavailable);
}

- (id)init {
    self = [super init];
	if (self) {
        laptopLidState = LaptopLidStateIsUnavailable;
    }
	return self;
}

- (void)dealloc {
    if (serialQueue) {
        [self doStop];
    }
}

- (BOOL)setupLidStateNotification {
    serialQueue = dispatch_queue_create("com.dustinrue.ControlPlane.LaptopLidEvidenceSource", DISPATCH_QUEUE_SERIAL);
    if (!serialQueue) {
        return NO;
    }
    dispatch_set_target_queue(serialQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));

    notifyPort = IONotificationPortCreate(kIOMasterPortDefault);
    if (!notifyPort) {
        return NO;
    }
    IONotificationPortSetDispatchQueue(notifyPort, serialQueue);

    io_service_t pmRootDomain = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPMrootDomain"));
    if (!pmRootDomain) {
        return NO;
    }

    kern_return_t kr = IOServiceAddInterestNotification(notifyPort, pmRootDomain, kIOGeneralInterest,
                                                        onPMrootDomainChange, &laptopLidState, &notification);
    IOObjectRelease(pmRootDomain);

    return (kr == KERN_SUCCESS);
}

- (void)removeLidStateNotificaiton {
    if (notification) {
        IOObjectRelease(notification);
        notification = 0;
    }
    
    if (notifyPort) {
        IONotificationPortSetDispatchQueue(notifyPort, NULL);
        IONotificationPortDestroy(notifyPort);
        notifyPort = NULL;
    }
    
    if (serialQueue) {
        serialQueue = NULL;
    }
}

- (NSString *)description {
    return NSLocalizedString(@"Create rules based on whether the laptop lid is opened or closed.", @"");
}

- (void)start {
    if (running) {
        return;
    }

    laptopLidState = [LaptopLidEvidenceSource isLidClosed];
    if (laptopLidState == LaptopLidStateIsUnavailable) {
        [self doStop];
        return;
    }

    if (![self setupLidStateNotification]) {
        DSLog(@"Failed to set up notificaitons for the laptop (clamshell) lid state");
        [self doStop];
        return;
    }

    [self setDataCollected:YES];
    running = YES;
}

- (void)stop {
    if (running) {
        [self doStop];
    }
}

- (void)doStop {
    [self removeLidStateNotificaiton];
    laptopLidState = LaptopLidStateIsUnavailable;

    [self setDataCollected:NO];
    running = NO;
}

- (void)goingToSleep:(NSNotification *)note {
#ifdef DEBUG_MODE
	DSLog(@"goingToSleep: %@", [note name]);
#endif
}

- (void)wakeFromSleep:(NSNotification *)note {
#ifdef DEBUG_MODE
	DSLog(@"wakeFromSleep: %@", [note name]);
#endif
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
	return ([rule[@"parameter"] intValue] == laptopLidState);
}

- (NSString *)name {
	return @"LaptopLid";
}

- (NSString *)getSuggestionLeadText:(NSString *)type {
	return NSLocalizedString(@"Laptop lid is", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions {
    return @[
        @{ @"type": @"LaptopLid",
           @"parameter": @(LaptopLidIsOpen),
           @"description": NSLocalizedString(@"Opened", @"") },
        @{ @"type": @"LaptopLid",
           @"parameter": @(LaptopLidIsClosed),
           @"description": NSLocalizedString(@"Closed", @"") }
    ];
}

- (NSString *)friendlyName {
    return NSLocalizedString(@"Laptop Lid Open/Closed State", @"");
}

@end
