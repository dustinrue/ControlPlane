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

@implementation TimeMachineDestinationAction

@synthesize destinationVolumePath;

- (id)init
{
	if (!(self = [super init]))
		return nil;
    
  	NSDictionary *destinationVolumePath;

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

    [tmdah getAllDestinations];
    //[NSThread sleepForTimeInterval:2];

    DSLog(@"tmdah came back with %@", [tmdah tediumResponse]);
    @try {
/*
		TediumApplication *Tedium = [SBApplication applicationWithBundleIdentifier: @"com.dustinrue.Tedium"];
        
        NSString *error;
        NSPropertyListFormat format;
        NSString *destinationsFromTedium = [Tedium allDestinations];
        NSData *theData = [destinationsFromTedium dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *destinations = [NSPropertyListSerialization propertyListFromData:theData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&error];
*/
        opts = [[NSMutableArray alloc] initWithCapacity:[[tmdah tediumResponse] count]];
 
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
    DSLog(@"registering for notifications");
    [tediumNotifications addObserver:self selector:@selector(didReceiveNotification:) name:@"com.dustinrue.Tedium.allDestinationsResponse" object:nil];
}

- (void) deRegisterForNotifications {
    [tediumNotifications removeObserver:self name:@"com.dustinrue.Tedium.allDestinationsResponse" object:nil];
}

- (void) didReceiveNotification:(NSNotification *) notification {
    [self setTediumResponse:[notification userInfo]];
    DSLog(@"got response %@",[self tediumResponse]);
    [self deRegisterForNotifications];
}

- (void) sendAllDestinationsRequest {
    DSLog(@"sending notification");

    [tediumNotifications postNotificationName:@"com.dustinrue.Tedium.allDestinationsRequest" object:nil userInfo:nil deliverImmediately:YES];
}

- (void) getAllDestinations {
    [NSThread detachNewThreadSelector:@selector(doGetAllDestinations) toTarget:self withObject:nil];
    
}

- (void) doGetAllDestinations {
    DSLog(@"doing the things");
    [self registerForNotifications];
    [self sendAllDestinationsRequest];
}

- (void) setDestination:(NSString *)newDestination {
    NSDictionary *args = [[[NSDictionary alloc] initWithObjectsAndKeys:newDestination, @"destinationVolumeName", nil] autorelease];
    [tediumNotifications postNotificationName:@"com.dustinrue.Tedium.setDestination" object:nil userInfo:args deliverImmediately:YES];
}
                                                                                                                     
                                                                                                        

@end




