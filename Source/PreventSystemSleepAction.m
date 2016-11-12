//
//  PreventSystemSleepAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 6/19/14.
//
//

#import "PreventSystemSleepAction.h"
#import <IOKit/pwr_mgt/IOPMLib.h>

@implementation PreventSystemSleepAction

- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Preventing system sleep.", @"");
	else
		return NSLocalizedString(@"Allowing system sleep.", @"");
}

- (BOOL) execute: (NSString **) errorString {
    IOPMAssertionID assertionID;
    IOReturn success = kIOReturnError;
    // kIOPMAssertionTypeNoDisplaySleep prevents display sleep,
    // kIOPMAssertionTypeNoIdleSleep prevents idle sleep
    
    PreventSystemSleepActionStorage *assertionIdStorage = [PreventSystemSleepActionStorage sharedStorage];
    
    
    if (turnOn && !([assertionIdStorage assertionID] > 0)) {
        //  NOTE: IOPMAssertionCreateWithName limits the string to 128 characters.
        CFStringRef reasonForActivity= CFSTR("ControlPlane is preventing system sleep");
        
        
        
        success = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep,
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
		*errorString = @"Unable to enable/disable system sleep.";
		return NO;
	} else
		return YES;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for Prevent System Sleep action is either \"1\" to prevent "
                             "system sleep or \"0\" to allow system sleep.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Toggle prevention of system sleep", @"");
}

+ (NSArray *) limitedOptions {
	return [NSArray arrayWithObjects:
            [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], @"option",
             NSLocalizedString(@"Allow System Sleep", @""), @"description", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"option",
             NSLocalizedString(@"Disallow System Sleep", @""), @"description", nil],
            nil];
}



+ (NSString *) friendlyName {
    return NSLocalizedString(@"Prevent System Sleep", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"System Preferences", @"");
}

@end

static PreventSystemSleepActionStorage *sharedStorage;

@implementation PreventSystemSleepActionStorage

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
