//
//  NetworkLocationAction.m
//  ControlPlane
//
//  Created by David Symonds on 4/07/07.
//

#import <SystemConfiguration/SCPreferences.h>
#import <SystemConfiguration/SCSchemaDefinitions.h>
#import "NetworkLocationAction.h"


@implementation NetworkLocationAction

#pragma mark Utility methods

+ (NSDictionary *) getAllSets
{
	SCPreferencesRef prefs = SCPreferencesCreate(NULL, CFSTR("ControlPlane"), NULL);
	SCPreferencesLock(prefs, true);

	CFDictionaryRef cf_dict = (CFDictionaryRef) SCPreferencesGetValue(prefs, kSCPrefSets);
	NSDictionary *dict = [NSDictionary dictionaryWithDictionary:(NSDictionary *) cf_dict];

	// Clean up
	SCPreferencesUnlock(prefs);
	CFRelease(prefs);

	return dict;
}

+ (NSString *)getCurrentSet
{
	SCPreferencesRef prefs = SCPreferencesCreate(NULL, CFSTR("ControlPlane"), NULL);
	SCPreferencesLock(prefs, true);

	CFStringRef cf_str = (CFStringRef) SCPreferencesGetValue(prefs, kSCPrefCurrentSet);
	NSMutableString *str = [NSMutableString stringWithString:(NSString *) cf_str];
	[str replaceOccurrencesOfString:[NSString stringWithFormat:@"/%@/", kSCPrefSets]
			     withString:@""
				options:0
				  range:NSMakeRange(0, [str length])];

	// Clean up
	SCPreferencesUnlock(prefs);
	CFRelease(prefs);

	return str;
}

#pragma mark -

- (id)init
{
	if (!(self = [super init]))
		return nil;

	networkLocation = [[NSString alloc] init];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super initWithDictionary:dict]))
		return nil;

	networkLocation = [[dict valueForKey:@"parameter"] copy];

	return self;
}

- (void)dealloc
{
	[networkLocation release];

	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];

	[dict setObject:[[networkLocation copy] autorelease] forKey:@"parameter"];

	return dict;
}

- (NSString *)description
{
	return [NSString stringWithFormat:NSLocalizedString(@"Changing network location to '%@'.", @""),
		networkLocation];
}

- (BOOL)execute:(NSString **)errorString
{
	// Using SCPreferences* to change the location requires a setuid binary,
	// so we just execute /usr/sbin/scselect to do the heavy lifting.
	NSDictionary *all_sets = [[self class] getAllSets];
	NSEnumerator *en = [all_sets keyEnumerator];
	NSString *key;
	NSDictionary *subdict;
	while ((key = [en nextObject])) {
		subdict = [all_sets valueForKey:key];
		if ([networkLocation isEqualToString:[subdict valueForKey:@"UserDefinedName"]])
			break;
	}
	if (!key) {
		*errorString = [NSString stringWithFormat:
				NSLocalizedString(@"No network location named \"%@\" exists!", @"Action error message"),
				networkLocation];
		return NO;
	}

	NSArray *args = [NSArray arrayWithObject:key];
	NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/sbin/scselect" arguments:args];
	[task waitUntilExit];
	if ([task terminationStatus] != 0) {
		*errorString = NSLocalizedString(@"Failed changing network location", @"Action error message");
		return NO;
	}
	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for NetworkLocation actions is the name of the "
				 "network location to select.", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Changing network location to", @"");
}

+ (NSArray *)limitedOptions
{
	NSMutableArray *loc_list = [NSMutableArray array];
	NSEnumerator *en = [[[self class] getAllSets] objectEnumerator];
	NSDictionary *set;
	while ((set = [en nextObject]))
		[loc_list addObject:[set valueForKey:@"UserDefinedName"]];
	[loc_list sortUsingSelector:@selector(localizedCompare:)];

	NSMutableArray *opts = [NSMutableArray arrayWithCapacity:[loc_list count]];
	en = [loc_list objectEnumerator];
	NSString *loc;
	while ((loc = [en nextObject]))
		[opts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			loc, @"option", loc, @"description", nil]];

	return opts;
}

- (id)initWithOption:(NSString *)option
{
	self = [super init];
	[networkLocation autorelease];
	networkLocation = [option copy];
	return self;
}

@end
