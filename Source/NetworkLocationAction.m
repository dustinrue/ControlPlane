//
//  NetworkLocationAction.m
//  ControlPlane
//
//  Created by David Symonds on 4/07/07.
//

#import <SystemConfiguration/SCNetworkConfiguration.h>
#import <SystemConfiguration/SCPreferences.h>
#import <SystemConfiguration/SCSchemaDefinitions.h>

#import "NetworkLocationAction.h"


@implementation NetworkLocationAction

#pragma mark Utility methods

static NSString* getCurrentLocationName() {
	SCPreferencesRef prefs = SCPreferencesCreate(NULL, CFSTR("ControlPlane"), NULL);
	SCPreferencesLock(prefs, true);

    SCNetworkSetRef currLoc = SCNetworkSetCopyCurrent(prefs);
    NSString *locName = [[(NSString *) SCNetworkSetGetName(currLoc) copy] autorelease];
    CFRelease(currLoc);

    SCPreferencesUnlock(prefs);
    CFRelease(prefs);

    return locName;
}

+ (NSDictionary *) getAllSets {
	SCPreferencesRef prefs = SCPreferencesCreate(NULL, CFSTR("ControlPlane"), NULL);
	SCPreferencesLock(prefs, true);

	CFDictionaryRef cf_dict = (CFDictionaryRef) SCPreferencesGetValue(prefs, kSCPrefSets);
	NSDictionary *dict = [NSDictionary dictionaryWithDictionary:(NSDictionary *) cf_dict];

	// Clean up
	SCPreferencesUnlock(prefs);
	CFRelease(prefs);

	return dict;
}

+ (NSString *)getCurrentSet {
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

- (id)init {
	if (!(self = [super init])) {
		return nil;
    }

	networkLocation = [[NSString alloc] init];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict {
	if (!(self = [super initWithDictionary:dict]))
		return nil;

	networkLocation = [dict[@"parameter"] copy];

	return self;
}

- (void)dealloc {
	[networkLocation release];

	[super dealloc];
}

- (NSMutableDictionary *)dictionary {
	NSMutableDictionary *dict = [super dictionary];
    dict[@"parameter"] = [[networkLocation copy] autorelease];
	return dict;
}

- (NSString *)description {
	return [NSString stringWithFormat:NSLocalizedString(@"Changing network location to '%@'.", @""),
		networkLocation];
}

- (BOOL)execute:(NSString **)errorString {
    if ([networkLocation isEqualToString:getCurrentLocationName()]) {
#ifdef DEBUG_MODE
        NSLog(@"Network location is already set to '%@'", networkLocation);
#endif
        return YES;
    }

    __block NSString *locationId;

	NSDictionary *allSets = [[self class] getAllSets];
    [allSets enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *subdict, BOOL *stop) {
        if ([networkLocation isEqualToString:[subdict valueForKey:@"UserDefinedName"]]) {
            locationId = key;
            *stop = YES;
        }
    }];

	if (!locationId) {
		*errorString = [NSString stringWithFormat:
				NSLocalizedString(@"No network location named \"%@\" exists!", @"Action error message"),
				networkLocation];
		return NO;
	}

    // Using SCPreferences* to change the location requires a setuid binary,
	// so we just execute /usr/sbin/scselect to do the heavy lifting.
	NSArray *args = [NSArray arrayWithObject:locationId];
	NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/sbin/scselect" arguments:args];
	[task waitUntilExit];
	if ([task terminationStatus] != 0) {
		*errorString = NSLocalizedString(@"Failed changing network location", @"Action error message");
		return NO;
	}

	return YES;
}

+ (NSString *)helpText {
	return NSLocalizedString(@"The parameter for NetworkLocation actions is the name of the "
				 "network location to select.", @"");
}

+ (NSString *)creationHelpText {
	return NSLocalizedString(@"Changing network location to", @"");
}

+ (NSArray *)limitedOptions {
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

- (id)initWithOption:(NSString *)option {
	self = [super init];
	[networkLocation autorelease];
	networkLocation = [option copy];
	return self;
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Network Location", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Networking", @"");
}

@end
