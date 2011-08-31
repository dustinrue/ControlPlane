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
	NSString *strippedVPNType = [[NSString alloc] initWithString:[vpnType substringFromIndex:1]];

	if (enabledPrefix == true)
		return [NSString stringWithFormat:NSLocalizedString(@"Connecting to default VPN of type '%@'.", @""),
			strippedVPNType];
	else
		return [NSString stringWithFormat:NSLocalizedString(@"Disconnecting from default VPN of type '%@'.", @""),
			strippedVPNType];
}

- (BOOL) execute: (NSString **) errorString {
	// TODO: maybe port this to use SCNetworkConnection
	
	@try {
		BOOL connect = ([vpnType characterAtIndex:0] == '+' ? YES : NO);
		NSString *tVPNType = [vpnType substringFromIndex: 1];
		SystemEventsApplication *SEvents = [SBApplication applicationWithBundleIdentifier: @"com.apple.systemevents"];
		
		// find service
		SystemEventsLocation *location = SEvents.networkPreferences.currentLocation;
		SystemEventsService *service = [location.services objectWithName: [NSString stringWithFormat:@"VPN (%@)", tVPNType]];
		
		// connect/disconnect
		if (service) {
			if (connect)
				[SEvents connect: service];
			else
				[SEvents disconnect: service];
		}
	} @catch (NSException *e) {
		*errorString = NSLocalizedString(@"Couldn't configure VPN!", @"In VPNAction");
		return NO;
	}
	
	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for VPN action is the type of the "
				 "VPN connection you wish to establish or disconnect.", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Establish/Disconnect the following VPN:", @"");
}

+ (NSArray *)limitedOptions
{
	NSMutableArray *opts = [NSMutableArray arrayWithCapacity:4];

	[opts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                     @"-PPTP", @"option", @"Disable default PPTP VPN", @"description", nil]];
	[opts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                     @"+PPTP", @"option", @"Enable default PPTP VPN", @"description", nil]];
	[opts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                     @"-L2TP", @"option", @"Disable default L2TP VPN", @"description", nil]];
	[opts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                     @"+L2TP", @"option", @"Enable default L2TP VPN", @"description", nil]];
    [opts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                     @"-Cisco IPSec", @"option", @"Disable default Cisco IPSec VPN", @"description", nil]];
    [opts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                     @"+Cisco IPSec", @"option", @"Enable default Cisco IPSec VPN", @"description", nil]];

	return opts;
}

- (id)initWithOption:(NSString *)option
{
	[self init];
	[vpnType autorelease];
	vpnType = [option copy];
	return self;
}

@end
