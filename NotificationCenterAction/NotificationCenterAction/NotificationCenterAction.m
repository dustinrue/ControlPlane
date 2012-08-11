//
//  NotificationCenterAction.m
//  NotificationCenterAction
//
//  Created by Dustin Rue on 8/10/12.
//  Copyright (c) 2012 Dustin Rue. All rights reserved.
//

#import "NotificationCenterAction.h"

@implementation NotificationCenterAction

@synthesize helperToolResponse;
@synthesize type;
@synthesize context;
@synthesize when;
@synthesize delay;
@synthesize enabled;
@synthesize turnOn;

+ (NSString *)typeForClass:(Class)klass {
    return NSLocalizedString(@"NotificationCenterAction", @"");
}

+ (Class)classForType:(NSString *)type {
    NSString *classString = [NSString stringWithFormat:@"%@Action", type];
	Class klass = NSClassFromString(classString);
	if (!klass) {
		NSLog(@"ERROR: No implementation class '%@'!", classString);
		return nil;
	}
	return klass;
}

+ (Action *)actionFromDictionary:(NSDictionary *)dict {
    NSString *type = [dict valueForKey:@"type"];
	if (!type) {
		NSLog(@"ERROR: Action doesn't have a type!");
		return nil;
	}
	Action *obj = [[[NotificationCenterAction classForType:type] alloc] initWithDictionary:dict];
	return obj;
}

- (id)init {
    self = [super init];
    
    /*
	if ([[self class] isEqualTo:[self class]]) {
		[NSException raise:@"Abstract Class Exception"
                    format:@"Error, attempting to instantiate Action directly."];
	}
     */
    
	if (!self)
		return nil;
    
	type = @"NotificationCenter";
	context = @"";
	when = @"Arrival";
	delay = [[NSNumber alloc] initWithDouble:0];
	enabled = [[NSNumber alloc] initWithBool:YES];
    
	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict {
    
	if ([[self class] isEqualTo:[self class]]) {
		[NSException raise:@"Abstract Class Exception"
                    format:@"Error, attempting to instantiate Action directly."];
	}
    
	if (!(self = [super init]))
		return nil;
    
	type = @"NotificationCenter";
	context = [[dict valueForKey:@"context"] copy];
	when = [[dict valueForKey:@"when"] copy];
	delay = [[dict valueForKey:@"delay"] copy];
	enabled = [[dict valueForKey:@"enabled"] copy];
    
	return self;
}

- (void)dealloc {
    
}

- (NSMutableDictionary *)dictionary {
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [type copy], @"type",
            [context copy], @"context",
            [when copy], @"when",
            [delay copy], @"delay",
            [enabled copy], @"enabled",
            nil];
}

+ (NSString *)helpTextForActionOfType:(NSString *)type {
    return @"";
}

- (NSComparisonResult)compareDelay:(Action *)other {

}

// To be implemented by descendant classes:
- (NSString *)description {
   	if (turnOn)
		return NSLocalizedString(@"Turning Notification Center Alerts on.", @"");
	else
		return NSLocalizedString(@"Turning Notification Center Alerts off.", @"");
}

- (BOOL)execute:(NSString **)errorString {
    NSLog(@"HI!");
    return YES;
}

+ (NSString *)helpText {
    return NSLocalizedString(@"The parameter for Toggle Notification Center Alerts actions is either \"1\" "
                             "or \"0\", depending on whether you want enable or disable Notification Center Alerts."
                             "", @"");
}

+ (NSString *)creationHelpText {
    return NSLocalizedString(@"Turn Notification Center Alerts", @"Will be followed by 'on' or 'off'");
}

+ (NSString *)friendlyName {
    return NSLocalizedString(@"Toggle Notification Center Alerts", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"System Preferences", @"");
}

+ (BOOL) shouldWaitForScreensaverExit {
    return YES;
}

+ (BOOL) shouldWaitForScreenUnlock {
    return YES;
}


- (BOOL)executeAppleScript:(NSString *)script {
    return YES;
}

- (NSArray *)executeAppleScriptReturningListOfStrings:(NSString *)script {
    return [NSArray array];
}



+ (NSArray *)limitedOptions {
    return [NSArray arrayWithObjects:
            [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"option",
             NSLocalizedString(@"on", @"Used in toggling actions"), @"description", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], @"option",
             NSLocalizedString(@"off", @"Used in toggling actions"), @"description", nil],
            nil];
}

- (id)initWithOption:(NSNumber *)option {
    
}

@end
