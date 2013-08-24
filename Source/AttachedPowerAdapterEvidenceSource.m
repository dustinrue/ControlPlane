//
//  AttachedPowerAdapterEvidenceSource.m
//  ControlPlane
//
//  Created by Dustin Rue on 8/27/12.
//
//

#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>

#import "AttachedPowerAdapterEvidenceSource.h"
#import "DSLogger.h"
#import "CPSystemInfo.h"


@interface AttachedPowerAdapterEvidenceSource ()

@property (strong,atomic) NSNumber *attachedPowerAdapter;

@end


@implementation AttachedPowerAdapterEvidenceSource

- (id)init {
	if (!(self = [super init])) {
		return nil;
    }
    
	return self;
}

- (void)dealloc {
	//[super dealloc];
}

- (NSString *)description {
    return NSLocalizedString(@"Create a rules based on what power adapter"
                             " is currently connected to your portable mac based on its serial number", @"");
}

- (void)doFullUpdate:(NSNotification *)notification {
    NSNumber *serialNumber = nil;

    CFDictionaryRef powerAdapterInfo = IOPSCopyExternalPowerAdapterDetails();
    if (powerAdapterInfo) {
        serialNumber = ((__bridge NSDictionary *) powerAdapterInfo)[@kIOPSPowerAdapterSerialNumberKey];
        CFRelease(powerAdapterInfo);
    }

    self.attachedPowerAdapter = serialNumber;
    [self setDataCollected:(serialNumber != nil)];

    if (notification) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
    }
}

- (void)start {
	if (running) {
		return;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(doFullUpdate:)
                                                 name:@"powerAdapterDidChangeNotification"
                                               object:nil];

	[self doFullUpdate:nil];

	running = YES;
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
    NSString *param = [rule[@"parameter"] stringValue];
    NSString *currentAdapter = [[self.attachedPowerAdapter stringValue] copy];

    BOOL match = [currentAdapter isEqualToString:param];

   // [currentAdapter release];

    return match;
}

- (NSString *)getSuggestionLeadText:(NSString *)type {
	return NSLocalizedString(@"The following application is active", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions {
    [self doFullUpdate:nil];

    NSNumber *serialNum = self.attachedPowerAdapter;
    NSString *descr = [NSString stringWithFormat:NSLocalizedString(@"Power adapter with serial: %@", @""), serialNum];
    NSArray *array = @[ @{ @"type": @"AttachedPowerAdapter", @"parameter": serialNum, @"description": descr } ];

    DSLog(@"stuff %@", array);
	return array;
}

- (NSString *)friendlyName {
    return NSLocalizedString(@"Attached Power Adapter", @"");
}

+ (BOOL)isEvidenceSourceApplicableToSystem {
    return [CPSystemInfo isPortable];
}

@end
