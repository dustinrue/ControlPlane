//
//  PowerEvidenceSource.m
//  ControlPlane
//
//  Created by Mark Wallis on 30/4/07.
//  Tweaks by David Symonds on 30/4/07.
//  Minor updates done by Vladimir Beloborodov (VladimirTechMan) on 25 Aug 2013.
//

#import <IOKit/IOKitLib.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>
#import "PowerEvidenceSource.h"
#import "CPSystemInfo.h"


#pragma mark -

@implementation PowerEvidenceSource {
	NSString *status;
}

- (id)init {
    self = [super init];
	if (!self) {
		return nil;
    }

	return self;
}

- (void)dealloc {
    [status release];
    [super dealloc];
}

- (NSString *)description {
    return NSLocalizedString(@"Create rules based on what power source your Mac is currently running on."
                             " Can include power adapter or battery.", @"");
}

- (void)doFullUpdate:(NSNotification *)notification {
	CFTypeRef blob = IOPSCopyPowerSourcesInfo();
	CFArrayRef list = IOPSCopyPowerSourcesList(blob);

	__block BOOL onBattery = YES;
    [(NSArray *) list enumerateObjectsUsingBlock:^(id source, NSUInteger idx, BOOL *stop) {
		NSDictionary *dict = (NSDictionary *) IOPSGetPowerSourceDescription(blob, (CFTypeRef) source);

		if ([dict[@kIOPSPowerSourceStateKey] isEqualToString:@kIOPSACPowerValue]) {
			onBattery = NO;
            *stop = YES;
        }
    }];

    CFRelease(list);
	CFRelease(blob);

    status = (onBattery) ? (@"Battery") : (@"A/C");
	[self setDataCollected:YES];

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

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"powerAdapterDidChangeNotification"
                                                  object:nil];

	status = nil;
	[self setDataCollected:NO];

	running = NO;
}

- (NSString *)name {
	return @"Power";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
	return status && [status isEqualToString:rule[@"parameter"]];
}

- (NSString *)getSuggestionLeadText:(NSString *)type {
	return NSLocalizedString(@"Being powered by", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions {
	return @[
        @{ @"type": @"Power", @"parameter": @"Battery", @"description": NSLocalizedString(@"Battery", @"") },
        @{ @"type": @"Power", @"parameter": @"A/C",     @"description": NSLocalizedString(@"Power Adapter", @"") },
    ];
}

- (void) goingToSleep:(id)arg {
    [self stop];
}

- (void) wakeFromSleep:(id)arg {
    [self start];
}

- (NSString *)friendlyName {
    return NSLocalizedString(@"Power Source", @"");
}

// as far as I know we don't know how to deal with attached UPS systems on
// non portable Macs, so lets assume this evidence source only works with
// laptops
/*
+ (BOOL) isEvidenceSourceApplicableToSystem {
    return [CPSystemInfo isPortable];
}
 */

@end
