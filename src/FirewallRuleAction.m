//
//  FirewallRuleAction.m
//  MarcoPolo
//
//  Created by Mark Wallis on 17/07/07.
//

#import "FirewallRuleAction.h"


@interface FirewallRuleAction (Private)

- (BOOL)isEnableRule;
- (NSString *)strippedRuleName;

@end

@implementation FirewallRuleAction

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
	NSString *name = [self strippedRuleName];
	
	if ([self isEnableRule])
		return [NSString stringWithFormat:NSLocalizedString( @"Enabling Firewall Rule '%@'.", @""), name];
	else
		return [NSString stringWithFormat:NSLocalizedString( @"Disabling Firewall Rule '%@'.", @""), name];
}

- (BOOL)execute:(NSString **)errorString
{
	// Strip off the first character which indicates either enabled or disabled
	BOOL isEnable = [self isEnableRule];
	NSString *name = [self strippedRuleName];

	// Locate the firewall preferences dictionary
	CFDictionaryRef dict = (CFDictionaryRef) CFPreferencesCopyAppValue(CFSTR("firewall"), CFSTR("com.apple.sharing.firewall"));

	// Create a mutable copy that we can update
	CFMutableDictionaryRef newDict = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, dict);	

	// Find the specific rule we which to enable
	CFMutableDictionaryRef val = (CFMutableDictionaryRef)CFDictionaryGetValue(newDict, name);

	if (!val) {
		*errorString = NSLocalizedString( @"Couldn't find requested firewall rule!", @"In FirewallRuleAction" );
		return NO;
	}

	// Alter the dictionary to set the enable flag
	uint32_t enabledVal = isEnable ? 1 : 0;

	CFNumberRef enabledRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &enabledVal);
	CFDictionarySetValue(val, @"enable", enabledRef);

	// Persist the changes to the preferences
	CFPreferencesSetValue(CFSTR("firewall"), newDict, CFSTR("com.apple.sharing.firewall"),
			      kCFPreferencesAnyUser, kCFPreferencesCurrentHost);
	CFPreferencesSynchronize(CFSTR("com.apple.sharing.firewall"), kCFPreferencesAnyUser,
				 kCFPreferencesCurrentHost );

	// Call the FirewallTool utility to reload the firewall rules from the preferences
	// TODO: Look for better ways todo this that don't require admin privileges.
	NSString *script = @"do shell script \"/usr/libexec/FirewallTool\" with administrator privileges";

	NSDictionary *errorDict;
	NSAppleScript *appleScript = [[[NSAppleScript alloc] initWithSource:script] autorelease];
	NSAppleEventDescriptor *returnDescriptor = [appleScript executeAndReturnError:&errorDict];

	if (!returnDescriptor) {
		*errorString = NSLocalizedString(@"Couldn't restart firewall with new configuration!",
						@"In FirewallRuleAction");
		return NO;
	}

	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString( @"The parameter for FirewallRule action is the name of the "
				  "firewall rule you wish to modify, prefixed with '+' or '-' to "
				  "enable or disable it, respectively.", @"" );
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Enable the firewall rule", @"");
}

+ (NSArray *)limitedOptions
{
	int cnt=0;
	
	// Locate the firewall preferences dictionary
	CFDictionaryRef dict = (CFDictionaryRef) CFPreferencesCopyAppValue(CFSTR("firewall"), CFSTR("com.apple.sharing.firewall"));
	int nameCount = CFDictionaryGetCount(dict);
	CFStringRef names[nameCount];

	// Get a full listing of all firewall rules
	CFDictionaryGetKeysAndValues(dict, (const void **)names, NULL);	

	NSMutableArray *opts = [NSMutableArray arrayWithCapacity:nameCount];

	for (cnt = 0; cnt < nameCount; ++cnt) {
		NSString *name = (NSString *) names[cnt];
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
