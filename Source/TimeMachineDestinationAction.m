//
//  TimeMachineDestinationAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 1/23/12.
//  Copyright (c) 2012 ControlPlane. All rights reserved.
//

#import "TimeMachineDestinationAction.h"
#import <ScriptingBridge/SBApplication.h>
#import "DSLogger.h"

@interface TimeMachineDestinationAction (Private)

+ (id<DOTediumApp>) getTediumApp;

@end

@implementation TimeMachineDestinationAction

@synthesize destinationVolumePath;

- (id)init
{
	if (!(self = [super init]))
		return nil;
    
	destinationVolumePath = @"";

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super initWithDictionary:dict]))
		return nil;
    
	destinationVolumePath = [[dict valueForKey:@"parameter"] copy];
    
	return self;
}

- (id)initWithOption:(NSString *)option
{
	if (!(self = [super init]))
		return nil;
	
	destinationVolumePath = [option copy];
	
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];
    
    DSLog(@"%@",dict);
	[dict setObject:[[destinationVolumePath copy] autorelease] forKey:@"parameter"];
    
	return dict;
}

- (NSString *)description
{
	return [NSString stringWithFormat:NSLocalizedString(@"Setting Time Machine destination to '%@'.", @""),
            destinationVolumePath];
}

- (BOOL) execute: (NSString **) errorString {
	@try {
		id<DOTediumApp> tedium = [TimeMachineDestinationAction getTediumApp];
		if (tedium)
			tedium.currentDestination = destinationVolumePath;
		else
			@throw [NSException exceptionWithName: @"ConnectionError"
										   reason: @"Couldn't connect to Tedium"
										 userInfo: nil];
	} @catch (NSException *e) {
		DSLog(@"Exception: %@", e);
		*errorString = NSLocalizedString(@"Couldn't set Time Machine backup destination!", @"In TimeMachineDestinationAction");
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
    NSMutableArray *opts = [NSMutableArray new];
	NSArray *volumes = nil;
	
    @try {
		// fetch configured destinations
		id<DOTediumApp> tedium = [TimeMachineDestinationAction getTediumApp];
		if (tedium)
			volumes = tedium.allDestinations;
		
		// error check
		if (!opts)
			@throw [NSException exceptionWithName: @"ConnectionError"
										   reason: @"Couldn't connect to Tedium"
										 userInfo: nil];
	} @catch (NSException *e) {
		DSLog(@"Exception: %@", e);
		opts = [NSArray array];
	}
	
	// process results
	for (NSString *volume in volumes)
		[opts addObject: [NSDictionary dictionaryWithObjectsAndKeys:
						  volume, @"option",
						  volume, @"description", nil]];
	
	return opts;
}

+ (id<DOTediumApp>) getTediumApp {
	id tedium = nil;
	
	tedium = [NSConnection rootProxyForConnectionWithRegisteredName: @"com.dustinrue.Tedium" host: nil];
	
	if (!tedium)
		DSLog(@"Couldn't connect to Tedium app");
	else
		[tedium setProtocolForProxy: @protocol(DOTediumApp)];
	
	return tedium;
}

@end
