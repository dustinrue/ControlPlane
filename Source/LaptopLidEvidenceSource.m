//
//  LaptopLidEvidenceSource.m
//  ControlPlane
//
//  Created by Vladimir Beloborodov on July 15, 2013.
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

@implementation LaptopLidEvidenceSource

+ (BOOL)isEvidenceSourceApplicableToModel:(NSString *)hwModel {
    return ([LaptopLidEvidenceSource isLidClosed] != LaptopLidStateIsUnavailable);
}

+ (LaptopLidStateType)isLidClosed {
    static io_registry_entry_t rootDomain = MACH_PORT_NULL;
    if (rootDomain == MACH_PORT_NULL) {
        rootDomain = IORegistryEntryFromPath(kIOMasterPortDefault,
                                             kIOPowerPlane ":/IOPowerConnection/IOPMrootDomain");
        if (rootDomain == MACH_PORT_NULL) {
            return LaptopLidStateIsUnavailable;
        }
    }

    int isClosed = LaptopLidStateIsUnavailable;

    CFBooleanRef state = (CFBooleanRef) IORegistryEntryCreateCFProperty(rootDomain, CFSTR(kAppleClamshellStateKey),
                                                                        kCFAllocatorDefault, 0);
    if (state != NULL) {
        isClosed = (int) CFBooleanGetValue(state);
        CFRelease(state);
    }

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

- (id)init {
    self = [super init];
	if (self) {
        [self setDataCollected:([LaptopLidEvidenceSource isLidClosed] != LaptopLidStateIsUnavailable)];
    }
	return self;
}

- (NSString *)description {
    return NSLocalizedString(@"Create rules based on whether the laptop lid is opened or closed.", @"");
}

- (void)start {
    running = YES;
}

- (void)stop {
    running = NO;
}

- (void)goingToSleep:(NSNotification*)note {
#ifdef DEBUG_MODE
	DSLog(@"goingToSleep: %@", [note name]);
#endif
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
	return ([rule[@"parameter"] intValue] == [LaptopLidEvidenceSource isLidClosed]);
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
