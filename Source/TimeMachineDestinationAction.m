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
    [destinationVolumePath release];
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
        *errorString = NSLocalizedString(@"Unable to set set Time Machine backup destination!", @"In TimeMachineDestinationAction");
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
    NSString* TediumPath = [[NSWorkspace sharedWorkspace] 
                            absolutePathForAppBundleWithIdentifier:@"com.dustinrue.Tedium"];
    if (!TediumPath) {
        [[[self new] autorelease] performSelectorOnMainThread:@selector(tediumNotInstalledAlert) withObject:self waitUntilDone:YES];
        return nil;
    }
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
			[opts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							 destination, @"option", 
                             destination, @"description", nil]];
        }
		
	} @catch (NSException *e) {
		DSLog(@"Exception: %@", e);
		opts = [NSMutableArray array];
	}


	return opts;
}
             

- (id)initWithOption:(NSString *)option
{
	self = [super init];
	[destinationVolumePath autorelease];
	destinationVolumePath = [option copy];
	return self;
}
         
-(void) tediumNotInstalledAlert {
    
    NSAlert *alert = [[NSAlert alloc] init];

    [alert setMessageText:NSLocalizedString(@"This feature requires Tedium",@"Tedium is not installed")];
    [alert setInformativeText:NSLocalizedString(@"To switch Time Machine backup destinations, you need to have Tedium installed.  Click 'Get Tedium' to visit the Tedium website",@"")];
    
    [alert addButtonWithTitle:NSLocalizedString(@"Get Tedium",@"Get Tedium")];
    [alert addButtonWithTitle:NSLocalizedString(@"OK","Dismiss the alert without doing anything, but not a cancel")];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSURL *downloadURL = [NSURL URLWithString:[[[NSBundle mainBundle] infoDictionary] valueForKey:@"TediumURL"]];
        [[NSWorkspace sharedWorkspace] openURL:downloadURL];
    }
    [alert release];
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Change Time Machine Destination", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Time Machine", @"");
}

@end
