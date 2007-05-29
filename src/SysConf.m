//
//  SysConf.m
//  MarcoPolo
//
//  Created by David Symonds on 4/09/06.
//

#import <SystemConfiguration/SCPreferences.h>
#import <SystemConfiguration/SCSchemaDefinitions.h>
#import "SysConf.h"


@implementation SysConf

+ (NSDictionary *) getAllSets
{
	SCPreferencesRef prefs = SCPreferencesCreate(NULL, CFSTR("MarcoPolo"), NULL);
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
	SCPreferencesRef prefs = SCPreferencesCreate(NULL, CFSTR("MarcoPolo"), NULL);
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

// Return the name of the current location
+ (NSString *)getCurrentLocation
{
	return [[[SysConf getAllSets] valueForKey:[SysConf getCurrentSet]]
					valueForKey:@"UserDefinedName"];
}

// Using SCPreferences* to change the location requires a setuid binary,
// so for now we just execute /usr/sbin/scselect to do the heavy lifting.
#define USE_SCSELECT_CMD

+ (BOOL)setCurrentLocation:(NSString *)location
{
	NSDictionary *all_sets = [SysConf getAllSets];
	NSEnumerator *en = [all_sets keyEnumerator];
	NSString *key;
	NSDictionary *subdict;
	while ((key = [en nextObject])) {
		subdict = [all_sets valueForKey:key];
		if ([location isEqualToString:[subdict valueForKey:@"UserDefinedName"]])
			break;
	}
	if (!key) {
		NSLog(@"+setCurrentLocation: \"%@\" isn't a known location!\n", location);
		return NO;
	}

#ifdef USE_SCSELECT_CMD
	NSArray *args = [NSArray arrayWithObject:key];
	NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/sbin/scselect" arguments:args];
	[task waitUntilExit];
	int rc;
	if ((rc = [task terminationStatus]) != 0) {
		NSLog(@"Oops -- scselect returned with %d.\n", rc);
		return NO;
	}
	return YES;
#else
	SCPreferencesRef prefs = SCPreferencesCreate(NULL, CFSTR("MarcoPolo"), NULL);
	if (!prefs) {
		NSLog(@"+setCurrentLocation: SCPreferencesCreate failed!\n");
		return NO;
	}
	if (!SCPreferencesLock(prefs, true))
		NSLog(@"LOCK #3 failed (%s).\n", SCErrorString(SCError()));
	else
		NSLog(@"LOCK #3 succeeded.\n");

	BOOL ret = YES;
	// XXX: this needs to run as root, else SCPreferencesCommitChanges fails.
	CFStringRef set_str = CFStringCreateWithFormat(NULL, NULL, CFSTR("/%@/%@"),
							kSCPrefSets, key);
	if (!SCPreferencesSetValue(prefs, kSCPrefCurrentSet, set_str)) {
		NSLog(@"+setCurrentLocation: SCPreferencesSetValue failed!\n");
		ret = NO;
		goto cleanup;
	} else if (!SCPreferencesCommitChanges(prefs)) {
		NSLog(@"+setCurrentLocation: SCPreferencesCommitChanges failed! (%s)\n",
		      SCErrorString(SCError()));
		NSLog(@"prefs is\n%@\n", prefs);
		ret = NO;
		goto cleanup;
	} else if (!SCPreferencesApplyChanges(prefs)) {
		NSLog(@"+setCurrentLocation: SCPreferencesApplyChanges failed!\n");
		ret = NO;
		goto cleanup;
	}

cleanup:
	// Clean up
	CFRelease(set_str);
	SCPreferencesUnlock(prefs);
	CFRelease(prefs);

	return ret;
#endif
}

+ (NSArray *)locationsEnumerate
{
	NSMutableArray *loc_list = [NSMutableArray array];

	NSDictionary *dict = [SysConf getAllSets];
	NSEnumerator *en = [dict objectEnumerator];
	NSDictionary *subdict;
	while ((subdict = [en nextObject])) {
		[loc_list addObject:[subdict valueForKey:@"UserDefinedName"]];
	}

	[loc_list sortUsingSelector:@selector(compare:)];

	return loc_list;
}

@end
