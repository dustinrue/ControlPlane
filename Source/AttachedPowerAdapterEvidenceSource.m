//
//  AttachedPowerAdapterEvidenceSource.m
//  ControlPlane
//
//  Created by Dustin Rue on 8/27/12.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>

#import "AttachedPowerAdapterEvidenceSource.h"
#import "DSLogger.h"
#import "CPSystemInfo.h"
#import "CPNotifications.h"


@interface AttachedPowerAdapterEvidenceSource ()

@property (strong,atomic) NSNumber *attachedPowerAdapter;

@end


@implementation AttachedPowerAdapterEvidenceSource

- (NSString *)description {
    return NSLocalizedString(@"Create a rules based on what power adapter"
                             " is currently connected to your portable mac based on its serial number", @"");
}

- (void)doFullUpdate:(NSNotification *)notification {
    NSNumber *serialNumber = nil;
    
    CFDictionaryRef powerAdapterInfo = IOPSCopyExternalPowerAdapterDetails();
    if (powerAdapterInfo) {
        CFNumberRef serialNumberRef = CFDictionaryGetValue(powerAdapterInfo, CFSTR(kIOPSPowerAdapterSerialNumberKey));
        serialNumber = [((__bridge NSNumber *) serialNumberRef) copy];
        if (serialNumber == nil) {
            DSLog(@"WARNING: Power adapter details are available, but don't contain the adapter's serial number.");
        }
        
        CFRelease(powerAdapterInfo);
    }
    else {
        CFTypeRef blob = IOPSCopyPowerSourcesInfo();
        if (blob) {
            NSString *powerSourceType = (__bridge NSString *) IOPSGetProvidingPowerSourceType(blob);
            if ([powerSourceType isEqualToString:@kIOPSACPowerValue]) {
                DSLog(@"WARNING: System is on AC power, but cannot provide power adapter details"
                      " due to an internal error.");
                
                NSString *title = NSLocalizedString(@"Cannot get power adapter S/N",
                                                    @"Title to warn users on failed attempts to get power adapter S/N");
                NSString *msg = NSLocalizedString(@"It is an internal system error."
                                                  " Try to re-plug the MagSafe connector.",
                                                  @"Shown when CP cannot get details about the attached power adapter");
                [CPNotifications postUserNotification:title withMessage:msg];
            }
            
            CFRelease(blob);
        }
        else {
            DSLog(@"WARNING: Failed to get a copy of power sources info.");
        }
    }
    
    NSNumber *attachedPowerAdapter = self.attachedPowerAdapter;
    if (!attachedPowerAdapter || ![serialNumber isEqualToNumber:attachedPowerAdapter]) {
        self.attachedPowerAdapter = serialNumber;
        [self setDataCollected:(serialNumber != nil)];
        if (notification) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
        }
    }
}

- (void)start {
	if (running) {
		return;
    }
    
	running = YES;
	[self doFullUpdate:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(doFullUpdate:)
                                                 name:@"powerAdapterDidChangeNotification"
                                               object:nil];
}

- (void)stop {
	if (!running) {
		return;
    }
    
	// remove notifications
	[[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"powerAdapterDidChangeNotification"
                                                  object:nil];
    
    self.attachedPowerAdapter = nil;
	[self setDataCollected:NO];
    
	running = NO;
}

- (NSString *)name {
	return @"AttachedPowerAdapter";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
    NSNumber *attachedPowerAdapter = self.attachedPowerAdapter;
    return (attachedPowerAdapter && [((NSNumber *) rule[@"parameter"]) isEqualToNumber:attachedPowerAdapter]);
}

- (NSString *)getSuggestionLeadText:(NSString *)type {
	return NSLocalizedString(@"The following power adapter is attached", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions {
    [self doFullUpdate:nil];
    
    NSNumber *serialNum = self.attachedPowerAdapter;
    NSString *descr = [NSString stringWithFormat:NSLocalizedString(@"Power adapter with serial: %@", @""), serialNum];
    NSArray *array = @[ @{ @"type": @"AttachedPowerAdapter", @"parameter": serialNum, @"description": descr } ];
    
#ifdef DEBUG_MODE
    DSLog(@"stuff %@", array);
#endif
	return array;
}

- (NSString *)friendlyName {
    return NSLocalizedString(@"Attached Power Adapter", @"");
}

+ (BOOL)isEvidenceSourceApplicableToSystem {
    return [CPSystemInfo isPortable];
}

@end
