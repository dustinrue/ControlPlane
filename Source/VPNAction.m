//
//  VPNAction.m
//  ControlPlane
//
//  Created by Mark Wallis on 18/07/07.
//  Updated by Dustin Rue on 8/3/2011.
//

#import "VPNAction.h"
#import <ScriptingBridge/SBApplication.h>
#import "System Events.h"
#import "DSLogger.h"

@implementation VPNAction

- (id)init
{
	if (!(self = [super init]))
		return nil;

	vpnType = [[NSString alloc] init];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super initWithDictionary:dict]))
		return nil;

	vpnType = [[dict valueForKey:@"parameter"] copy];

	return self;
}

- (void)dealloc
{
	[vpnType release];

	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];

	[dict setObject:[[vpnType copy] autorelease] forKey:@"parameter"];

	return dict;
}

- (NSString *)description
{
	// Strip off the first character which indicates either enabled or disabled
	bool enabledPrefix = false;
	if ([vpnType characterAtIndex:0] == '+')
		enabledPrefix = true;
	NSString *strippedVPNType = [vpnType substringFromIndex:1];

	if (enabledPrefix == true)
		return [NSString stringWithFormat:NSLocalizedString(@"Connecting to VPN '%@'.", @""),
			strippedVPNType];
	else
		return [NSString stringWithFormat:NSLocalizedString(@"Disconnecting from VPN '%@'.", @""),
			strippedVPNType];
}

- (BOOL) execute: (NSString **) errorString {
	// TODO: maybe port this to use SCNetworkConnection
	
	@try {
		BOOL connect = ([vpnType characterAtIndex:0] == '+' ? YES : NO);
		NSString *tVPNName = [vpnType substringFromIndex: 1];
		SystemEventsApplication *SEvents = [SBApplication applicationWithBundleIdentifier: @"com.apple.systemevents"];
		
		// find service
		SystemEventsLocation *location = SEvents.networkPreferences.currentLocation;
		SystemEventsService *service = [location.services objectWithName:[NSString stringWithFormat:@"%@", tVPNName]];
        
        // no service found? try legacy format.
		service = service ? service : [location.services objectWithName:[NSString stringWithFormat:@"VPN (%@)", tVPNName]];
		
		// connect/disconnect
		if (service) {
			if (connect)
				[SEvents connect: service];
			else
				[SEvents disconnect: service];
		}
	} @catch (NSException *e) {
		DSLog(@"Exception: %@", e);
		*errorString = NSLocalizedString(@"Couldn't configure VPN!", @"In VPNAction");
		return NO;
	}
	
	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for VPN action is the name of the "
				 "VPN connection you wish to establish or disconnect.", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Establish/Disconnect the following VPN:", @"");
}

+ (NSArray *)limitedOptions
{
	NSMutableArray *opts = [NSMutableArray array];
    
    // loop through all services
    SystemEventsApplication *SEvents = [SBApplication applicationWithBundleIdentifier: @"com.apple.systemevents"];
    SystemEventsLocation *location = SEvents.networkPreferences.currentLocation;
    
    for (SystemEventsService *service in location.services)
    {
        // only add vpns, not other services
        if (!(service.kind == 10 || service.kind == 12 || service.kind == 15)) continue;
        
        [opts addObject:
         @{
            @"option": [NSString stringWithFormat:@"+%@", service.name],
            @"description": [NSString stringWithFormat:@"Connect VPN '%@'", service.name]
         }];
        [opts addObject:
         @{
            @"option": [NSString stringWithFormat:@"-%@", service.name],
            @"description": [NSString stringWithFormat:@"Disconnect VPN '%@'", service.name]
         }];
    }
    
    [opts addObject:
     @{
        @"option": @"+<name>",
        @"description": @"Connect other VPN"
     }];
    [opts addObject:
     @{
        @"option": @"-<name>",
        @"description": @"Disconnect other VPN"
     }];
    
	return opts;
}

- (id)initWithOption:(NSString *)option
{
	self = [super init];
	[vpnType autorelease];
	vpnType = [option copy];
	return self;
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"VPN", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Networking", @"");
}

@end
