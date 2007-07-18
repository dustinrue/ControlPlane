//
//  FirewallRuleAction.m
//  MarcoPolo
//
//  Created by Mark Wallis on 17/07/07.
//

#import "FirewallRuleAction.h"


@implementation FirewallRuleAction

- (id)init
{
	if (!(self = [super init]))
		return nil;

	ruleName = [[NSString alloc] init];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super init]))
		return nil;

	ruleName = [[dict valueForKey:@"parameter"] copy];

	return self;
}

- (void)dealloc
{
	[ruleName release];

	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];

	[dict setObject:[[ruleName copy] autorelease] forKey:@"parameter"];

	return dict;
}

- (NSString *)description
{
	// Strip off the first character which indicates either enabled or disabled
	bool enabledPrefix = false;
	if ([ruleName characterAtIndex:0] == '+')
		enabledPrefix = true;
	NSString *strippedRuleName = [[NSString alloc] initWithString: [ruleName substringFromIndex:1] ];
	
	if (enabledPrefix == true)
		return [NSString stringWithFormat:NSLocalizedString( @"Enabling Firewall Rule '%@'.", @"" ),
			strippedRuleName];
	else
		return [NSString stringWithFormat:NSLocalizedString( @"Disabling Firewall Rule '%@'.", @"" ),
			strippedRuleName];
}

- (BOOL)execute:(NSString **)errorString
{
	// Strip off the first character which indicates either enabled or disabled
	bool enabledPrefix = false;
	if ([ruleName characterAtIndex:0] == '+')
		enabledPrefix = true;
	NSString *strippedRuleName = [[NSString alloc] initWithString: [ruleName substringFromIndex:1] ];

	// Locate the firewall preferences dictionary
	CFDictionaryRef dict = (CFDictionaryRef) CFPreferencesCopyAppValue( CFSTR("firewall"), 
																	    CFSTR("com.apple.sharing.firewall") );
	
	// Create a mutable copy that we can update
	CFMutableDictionaryRef newDict = CFDictionaryCreateMutableCopy( kCFAllocatorDefault, 0, dict );	
	
	// Find the specific rule we which to enable
	CFMutableDictionaryRef val = (CFMutableDictionaryRef)CFDictionaryGetValue( newDict, strippedRuleName );
	
	if (val == NULL)
	{
		*errorString = NSLocalizedString( @"Couldn't find requested firewall rule!", @"In FirewallRuleAction" );
		return NO;
	}
	
	// Alter the dictionary to set the enable flag
	uint32_t	enabledVal = 1;
	
	if (enabledPrefix == false)
		enabledVal = 0;
	
	CFNumberRef enabledRef = CFNumberCreate( kCFAllocatorDefault, kCFNumberIntType, &enabledVal );
	CFDictionarySetValue( val, @"enable", enabledRef );
	
	// Persist the changes to the preferences
	CFPreferencesSetValue( CFSTR("firewall"), newDict, CFSTR("com.apple.sharing.firewall"), 
						   kCFPreferencesAnyUser, kCFPreferencesCurrentHost);
	CFPreferencesSynchronize( CFSTR("com.apple.sharing.firewall"), kCFPreferencesAnyUser, 
	                          kCFPreferencesCurrentHost );
	
	// Call the FirewallTool utility to reload the firewall rules from the preferences
	// TODO: Look for better ways todo this that don't require admin privileges.
	NSString *script = [NSString stringWithFormat:
		@"do shell script \"/usr/libexec/FirewallTool\" with administrator privileges"];
	
	NSDictionary* errorDict;
	NSAppleScript* appleScript = [[NSAppleScript alloc] initWithSource: script];
    NSAppleEventDescriptor* returnDescriptor = [appleScript executeAndReturnError: &errorDict];
    [appleScript release];

    if (returnDescriptor == NULL)
    {
		*errorString = NSLocalizedString( @"Couldn't restart firewall with new configuration!", 
										  @"In FirewallRuleAction" );
		return NO;
	}

	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString( @"The parameter for FirewallRule action is the name of the "
				              "firewall rule you wish to enable or disable.", @"" );
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Enable the firewall rule ", @"");
}

+ (NSArray *)limitedOptions
{
	int cnt=0;
	
	// Locate the firewall preferences dictionary
	CFDictionaryRef dict = (CFDictionaryRef) CFPreferencesCopyAppValue( CFSTR("firewall"), 
	                                                                    CFSTR("com.apple.sharing.firewall") );
	int nameCount = CFDictionaryGetCount( dict );
	CFStringRef names[nameCount];

	// Get a full listing of all firewall rules
	CFDictionaryGetKeysAndValues( dict, (const void**)names, NULL );	

	NSMutableArray *opts = [NSMutableArray arrayWithCapacity:nameCount];
	
	for (cnt=0; cnt<nameCount; cnt++)
	{
		NSString *name = (NSString *)names[cnt];
		NSString *enableFlag = @"+";
		NSString *disableFlag = @"-";
		NSString *enableTag = @"Enable ";
		NSString *disableTag = @"Disable ";
		NSString *enableName = [enableFlag stringByAppendingString:name];
		NSString *disableName = [disableFlag stringByAppendingString:name];
		NSString *enableDesc = [enableTag stringByAppendingString:name];
		NSString *disableDesc = [disableTag stringByAppendingString:name];
		
		[opts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
				disableName, @"option", disableDesc, @"description", nil]];	
		[opts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
				enableName, @"option", enableDesc, @"description", nil]];
	}

	return opts;
}

- (id)initWithOption:(NSString *)option
{
	[self init];
	[ruleName autorelease];
	ruleName = [option copy];
	return self;
}

@end
