//
//  FirewallRuleAction.m
//  ControlPlane
//
//  Created by Mark Wallis on 17/07/07.
//  Tweaks by David Symonds on 18/07/07.
//

#import "FirewallRuleAction.h"


@interface FirewallRuleAction (Private)

- (BOOL)isEnableRule;
- (NSString *)strippedRuleName;

@end

@implementation FirewallRuleAction

static NSLock *sharedLock = nil;

+ (void)initialize
{
	sharedLock = [[NSLock alloc] init];
}

- (BOOL)isEnableRule
{
	return ([ruleName characterAtIndex:0] == '+');
}

- (NSString *)strippedRuleName
{
	return [ruleName substringFromIndex:1];
}

- (id)init
{
	if (!(self = [super init]))
		return nil;

	ruleName = [[NSString alloc] init];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super initWithDictionary:dict]))
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
	NSString *name = [self strippedRuleName];

	if ([self isEnableRule])
		return [NSString stringWithFormat:NSLocalizedString(@"Enabling Firewall Rule '%@'.", @""), name];
	else
		return [NSString stringWithFormat:NSLocalizedString(@"Disabling Firewall Rule '%@'.", @""), name];
}

- (BOOL)execute:(NSString **)errorString {
	*errorString = @"Sorry, FirewallRuleAction isn't supported in Snow Leopard (or higher) yet.";
	return NO;
	
/** 
	// Strip off the first character which indicates either enabled or disabled
	BOOL isEnable = [self isEnableRule];
	NSString *name = [self strippedRuleName];

	[sharedLock lock];

	// Locate the firewall preferences dictionary
	CFDictionaryRef dict = (CFDictionaryRef) CFPreferencesCopyAppValue(CFSTR("firewall"), CFSTR("com.apple.sharing.firewall"));

	// Create a mutable copy that we can update
	CFMutableDictionaryRef newDict = CFDictionaryCreateMutableCopy(NULL, 0, dict);
	CFRelease(dict);

	// Find the specific rule we wish to enable
	CFMutableDictionaryRef val = (CFMutableDictionaryRef) CFDictionaryGetValue(newDict, name);

	if (!val) {
		*errorString = NSLocalizedString(@"Couldn't find requested firewall rule!", @"In FirewallRuleAction");
		[sharedLock unlock];
		return NO;
	}

	// Alter the dictionary to set the enable flag
	uint32_t enabledVal = isEnable ? 1 : 0;
	CFNumberRef enabledRef = CFNumberCreate(NULL, kCFNumberIntType, &enabledVal);
	CFDictionarySetValue(val, @"enable", enabledRef);

	// Write the changes to the preferences
	CFPreferencesSetValue(CFSTR("firewall"), newDict, CFSTR("com.apple.sharing.firewall"),
			      kCFPreferencesAnyUser, kCFPreferencesCurrentHost);
	CFPreferencesSynchronize(CFSTR("com.apple.sharing.firewall"), kCFPreferencesAnyUser,
				 kCFPreferencesCurrentHost);
	CFRelease(newDict);

	// Call the FirewallTool utility to reload the firewall rules from the preferences
	// TODO: Look for better ways todo this that don't require admin privileges.
	NSString *script = @"do shell script \"/usr/libexec/FirewallTool\" with administrator privileges";

	NSDictionary *errorDict;
	NSAppleScript *appleScript = [[[NSAppleScript alloc] initWithSource:script] autorelease];
	NSAppleEventDescriptor *returnDescriptor = [appleScript executeAndReturnError:&errorDict];

	[sharedLock unlock];

	if (!returnDescriptor) {
		*errorString = NSLocalizedString(@"Couldn't restart firewall with new configuration!",
						 @"In FirewallRuleAction");
		return NO;
	}

	return YES;*/
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for FirewallRule action is the name of the "
				 "firewall rule you wish to modify, prefixed with '+' or '-' to "
				 "enable or disable it, respectively.", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Set the following firewall rule:", @"");
}

+ (NSArray *)limitedOptions
{
	// Locate the firewall preferences dictionary
	NSDictionary *dict = (NSDictionary *) CFPreferencesCopyAppValue(CFSTR("firewall"), CFSTR("com.apple.sharing.firewall"));
	[dict autorelease];

	NSMutableArray *opts = [NSMutableArray arrayWithCapacity:[dict count]];

	NSEnumerator *en = [dict keyEnumerator];
	NSString *name;
	while ((name = [en nextObject])) {
		NSString *enableOpt = [NSString stringWithFormat:@"+%@", name];
		NSString *disableOpt = [NSString stringWithFormat:@"-%@", name];
		NSString *enableDesc = [NSString stringWithFormat:NSLocalizedString(@"Enable %@", @"In FirewallRuleAction"), name];
		NSString *disableDesc = [NSString stringWithFormat:NSLocalizedString(@"Disable %@", @"In FirewallRuleAction"), name];

		[opts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			enableOpt, @"option", enableDesc, @"description", nil]];
		[opts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			disableOpt, @"option", disableDesc, @"description", nil]];
	}

	return opts;
}

- (id)initWithOption:(NSString *)option
{
	self = [super init];
	[ruleName autorelease];
	ruleName = [option copy];
	return self;
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Firewall Rule", @"");
}

@end
