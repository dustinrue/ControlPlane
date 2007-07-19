//
//  VPNAction.m
//  MarcoPolo
//
//  Created by Mark Wallis on 18/07/07.
//

#import "VPNAction.h"
#import "SystemConfiguration/SCNetworkConfiguration.h"

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
	if (!(self = [super init]))
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
	NSString *strippedVPNType = [[NSString alloc] initWithString: [vpnType substringFromIndex:1] ];
	
	if (enabledPrefix == true)
		return [NSString stringWithFormat:NSLocalizedString( @"Connecting to default VPN of type '%@'.", @"" ),
			strippedVPNType];
	else
		return [NSString stringWithFormat:NSLocalizedString( @"Disconnecting from default VPN of type '%@'.", @"" ),
			strippedVPNType];
}

- (BOOL)execute:(NSString **)errorString
{
	NSString *script;

	// Strip off the first character which indicates either enabled or disabled
	bool enabledPrefix = false;
	if ([vpnType characterAtIndex:0] == '+')
		enabledPrefix = true;
	NSString *strippedVPNType = [[NSString alloc] initWithString: [vpnType substringFromIndex:1] ];

	if (enabledPrefix)
	{
		// Call the Internet Connect Applescript to connect to the VPN.
		script = [NSString stringWithFormat:
			@"tell application \"Internet Connect\"\n" 
			 "     connect configuration (get name of %@ configuration 1)\n" 
			 "end tell", strippedVPNType];
	}
	else
	{
		// Call the Internet Connect Applescript to connect to the VPN.
		script = [NSString stringWithFormat:
			@"tell application \"Internet Connect\"\n" 
			 "     disconnect configuration (get name of %@ configuration 1)\n"  
			 "end tell", strippedVPNType];	
	}
	
	NSDictionary* errorDict;
	NSAppleScript* appleScript = [[NSAppleScript alloc] initWithSource: script];
	NSAppleEventDescriptor* returnDescriptor = [appleScript executeAndReturnError: &errorDict];
	[appleScript release];

	if (returnDescriptor == NULL)
	{
		*errorString = NSLocalizedString( @"Couldn't configure VPN with Internet Connect Applescript!", 
										  @"In VPNAction" );
		return NO;
	}

	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString( @"The parameter for VPN action is the type of the "
				              "VPN connection you wish to establish or disconnect.", @"" );
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Establish/Disconnect the default VPN of type ", @"");
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
