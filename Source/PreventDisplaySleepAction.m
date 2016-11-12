//
//  PreventDisplaySleepAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 2/7/13.
//
//

#import "PreventDisplaySleepAction.h"
#import <IOKit/pwr_mgt/IOPMLib.h>

@implementation PreventDisplaySleepAction


- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Preventing display sleep.", @"");
	else
		return NSLocalizedString(@"Allowing display sleep.", @"");
}

- (BOOL) execute: (NSString **) errorString {
    IOPMAssertionID assertionID;
    IOReturn success = kIOReturnError;
    // kIOPMAssertionTypeNoDisplaySleep prevents display sleep,
    // kIOPMAssertionTypeNoIdleSleep prevents idle sleep

    PreventDisplaySleepActionStorage *assertionIdStorage = [PreventDisplaySleepActionStorage sharedStorage];
    
    
    if (turnOn && !([assertionIdStorage assertionID] > 0)) {
        //  NOTE: IOPMAssertionCreateWithName limits the string to 128 characters.
        CFStringRef reasonForActivity= CFSTR("ControlPlane is preventing display sleep");
        

        
        success = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep,
                                                       kIOPMAssertionLevelOn, reasonForActivity, &assertionID);
        
        [assertionIdStorage setAssertionID:assertionID];
    }
    else if (!turnOn && [assertionIdStorage assertionID] > 0) {
        assertionID = [assertionIdStorage assertionID];
        
        if (assertionID)
            success = IOPMAssertionRelease(assertionID);
        
        [assertionIdStorage setAssertionID:0];
    }
	
	
	// result
	if (success != kIOReturnSuccess && [assertionIdStorage assertionID] != 0) {
		*errorString = @"Unable to enable/disable display sleep.";
		return NO;
	} else
		return YES;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for Prevent Display Sleep action is either \"1\" to prevent "
                             "display sleep or \"0\" to allow display sleep.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Toggle prevention of display sleep", @"");
}

+ (NSArray *) limitedOptions {
	return [NSArray arrayWithObjects:
            [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], @"option",
             NSLocalizedString(@"Allow Display Sleep", @""), @"description", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"option",
             NSLocalizedString(@"Disallow Display Sleep", @""), @"description", nil],
            nil];
}



+ (NSString *) friendlyName {
    return NSLocalizedString(@"Prevent Display Sleep", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"System Preferences", @"");
}

@end

static PreventDisplaySleepActionStorage *sharedStorage;

@implementation PreventDisplaySleepActionStorage

+ (id) sharedStorage {
    @synchronized(self) {
        if(sharedStorage == nil) {
            sharedStorage = [[super allocWithZone:NULL] init];
            sharedStorage.assertionID = 0;
        }
    }
    
    return sharedStorage;
}

+ (id) allocWithZone:(NSZone *)zone {
    return [[self sharedStorage] retain];
}

- (id) copyWithZone:(NSZone *)zone {
    return self;
}
- (id) retain {
    return self;
}
- (NSUInteger)retainCount {
    return UINT_MAX; //denotes an object that cannot be released
}
- (oneway void)release {
    // never release
}

- (id)autorelease {
    return self;
}

- (id)init {
    self = [super init];
    
    return self;
}

@end
