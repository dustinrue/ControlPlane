//
//  TimeMachineDestinationAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 1/23/12.
//  Copyright (c) 2012 ControlPlane. All rights reserved.
//

#import "TimeMachineDestinationAction.h"
#import <ScriptingBridge/SBApplication.h>
#import "Tedium.h"
#import "DSLogger.h"

@implementation TimeMachineDestinationAction

@synthesize destinationVolumePath;

- (id)init
{
	if (!(self = [super init]))
		return nil;
    
  	static NSDictionary *destinationVolumePath;

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
    DSLog(@"%@",dict);
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
	@try {
		TediumApplication *Tedium = [SBApplication applicationWithBundleIdentifier: @"com.dustinrue.Tedium"];
		
        [Tedium setDestination:destinationVolumePath];
		
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
    NSMutableArray *opts = nil;
	
    TimeMachineDestinationActionSingleton *tmdah = [TimeMachineDestinationActionSingleton sharedSingleton];


    // CP is going to now issue a notification to Tedium to see if it responds
    // with a list of configured destinations

    
    [tmdah registerForNotifications];
    
    for (int i = 0; i < 3 && [[tmdah tediumResponse] count] < 1; i++ ) {
        [tmdah sendAllDestinationsRequest];
        [NSThread sleepForTimeInterval:0.3];

    }
    [NSThread  sleepForTimeInterval:10];
    DSLog(@"got %@", [tmdah tediumResponse]);
    @try {
		TediumApplication *Tedium = [SBApplication applicationWithBundleIdentifier: @"com.dustinrue.Tedium"];
        
        NSString *error;
        NSPropertyListFormat format;
        NSString *destinationsFromTedium = [Tedium allDestinations];
        NSData *theData = [destinationsFromTedium dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *destinations = [NSPropertyListSerialization propertyListFromData:theData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&error];

        opts = [[NSMutableArray alloc] initWithCapacity:[destinations count]];
		for (NSDictionary *destination in [[tmdah tediumResponse] objectForKey:@"destinations"]) {
            DSLog(@"destination is %@", destination);
			[opts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							 [destination valueForKey:@"destinationVolumePath"], @"option", 
                             [destination valueForKey:@"destinationVolumePath"], @"description", nil]];
        }
		
	} @catch (NSException *e) {
		DSLog(@"Exception: %@", e);
		opts = [NSArray array];
	}
	
    DSLog(@"leaving limitedOptions");
	return opts;
}
             
 - (void) didReceiveNotificationResponse:(NSNotification *) notification {
     DSLog(@"huh %@", [notification userInfo]);
     TimeMachineDestinationActionSingleton *tmdas = [TimeMachineDestinationActionSingleton sharedSingleton];
     [tmdas setTediumResponse:[notification userInfo]];

}

- (id)initWithOption:(NSString *)option
{
	self = [super init];
	
	destinationVolumePath = [option copy];

	return self;
}

@end

@implementation TimeMachineDestinationActionSingleton

static TimeMachineDestinationActionSingleton *_timeMachineDestinationActionSingleton = nil;

@synthesize tediumResponse;

+ (id) sharedSingleton {
    @synchronized([TimeMachineDestinationActionSingleton class]) {
        if (!_timeMachineDestinationActionSingleton)
            _timeMachineDestinationActionSingleton = [[self alloc] init];
        
        return _timeMachineDestinationActionSingleton;
    }
    
    
    return self;
}

+ (id) alloc {
    @synchronized([TimeMachineDestinationActionSingleton class]) {
        NSAssert(_timeMachineDestinationActionSingleton == nil, @"Attempted to allocate a second instance of TimeMachineDestinationActionSingleton");
        _timeMachineDestinationActionSingleton = [super alloc];
        return _timeMachineDestinationActionSingleton;
    }
    
    return nil;
}

- (id) init {
    self = [super init];
    NSLog(@"%@", tediumResponse);
    if (self != nil) {
        tediumResponse = [[NSDictionary alloc] init];
        tediumNotifications = [NSDistributedNotificationCenter defaultCenter];
    }
    
    return self;
}

- (void) registerForNotifications {
    [tediumNotifications addObserver:self selector:@selector(didReceiveNotification:) name:@"com.dustinrue.Tedium.allDestinationsResponse" object:nil];
}

- (void) didReceiveNotification:(NSNotification *) notification {
    DSLog(@"got response %@",[notification userInfo]);

    [self setTediumResponse:[notification userInfo]];
}

- (void) sendAllDestinationsRequest {
    DSLog(@"sending notification");

    [tediumNotifications postNotificationName:@"com.dustinrue.Tedium.allDestinationsRequest" object:nil userInfo:nil deliverImmediately:YES];
}

@end




