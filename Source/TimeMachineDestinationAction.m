//
//  TimeMachineDestinationAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 1/23/12.
//  Copyright (c) 2012 ControlPlane. All rights reserved.
//

#import "TimeMachineDestinationAction.h"
#import "DSLogger.h"

@implementation TimeMachineDestinationAction

@synthesize destinationVolumePath;

- (id)init
{
	if (!(self = [super init]))
		return nil;
    
	destinationVolumePath = [[NSString alloc] init];
	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super initWithDictionary:dict]))
		return nil;
    
	destinationVolumePath = [[dict valueForKey:@"parameter"] copy];
    
	return self;
}

- (void)dealloc
{
    
	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];
    
	[dict setObject:[[destinationVolumePath copy] autorelease] forKey:@"parameter"];
    
	return dict;
}

- (NSString *)description
{
	return [NSString stringWithFormat:NSLocalizedString(@"Setting Time Machine destination to '%@'.", @""),
            destinationVolumePath];
}

- (BOOL) execute: (NSString **) errorString {

    NSString *script = [NSString stringWithFormat:
                            @"tell application \"Tedium\"\n"
                            "    set current destination to \"%@\"\n"
                            "end tell\n", destinationVolumePath];
        
    if (![self executeAppleScript:script]) {
        *errorString = NSLocalizedString(@"Couldn't set Time Machine Backup Destination!", @"In TimeMachineDestinationAction");
        return NO;
    }

	
	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for TimeMachine actions is the name of the "
							 "new Time Machine backup destination.", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Set Time Machine's backup destination to", @"");
}

+ (NSArray *) limitedOptions {
    
	NSMutableArray *opts = nil;
    
    @try {
        NSString *script =
		@"tell application \"Tedium\"\n"
		"  get destinationVolumeName of every destination\n"
		"end tell\n";
        
        NSArray *list = [[[self new] autorelease] executeAppleScriptReturningListOfStrings:script];
        if (!list)		// failure
            return [NSArray array];

        opts = [NSMutableArray arrayWithCapacity:[list count]];
    
		for (NSString *destination in list) {
            DSLog(@"destination is %@", destination);
			[opts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							 destination, @"option", 
                             destination, @"description", nil]];
        }
		
	} @catch (NSException *e) {
		DSLog(@"Exception: %@", e);
		opts = [NSArray array];
	}

    NSLog(@"returning %@", opts);
	return opts;
}
             

- (id)initWithOption:(NSString *)option
{
	self = [super init];
	[destinationVolumePath autorelease];
	destinationVolumePath = [option copy];
	return self;
}

@end