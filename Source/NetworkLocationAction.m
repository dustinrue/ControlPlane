//
//  NetworkLocationAction.m
//  ControlPlane
//
//  Created by David Symonds on 4/07/07.
//  Modified by Vladimir Beloborodov (VladimirTechMan) on 12 June 2013.
//  Modified by Vladimir Beloborodov (VladimirTechMan) on 11 May 2014.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import <SystemConfiguration/SCNetworkConfiguration.h>
#import <SystemConfiguration/SCPreferences.h>
#import <SystemConfiguration/SCSchemaDefinitions.h>

#import "NetworkLocationAction.h"


@implementation NetworkLocationAction

#pragma mark Utility methods

+ (NSDictionary *)getAllSets {
	NSDictionary *dict = nil;

    SCPreferencesRef prefs = SCPreferencesCreate(NULL, CFSTR("ControlPlane"), NULL);
	SCPreferencesLock(prefs, true);

	CFPropertyListRef cfDict = (CFDictionaryRef) SCPreferencesGetValue(prefs, kSCPrefSets);
    if ((cfDict != NULL) && (CFGetTypeID(cfDict) == CFDictionaryGetTypeID())) {
        dict = [NSDictionary dictionaryWithDictionary:(__bridge NSDictionary *)cfDict];
    }

	SCPreferencesUnlock(prefs);
	CFRelease(prefs);

	return dict;
}

#pragma mark -

- (id)initWithOption:(NSString *)option {
	self = [super init];
    if (self) {
        networkLocation = [option copy];
    }
	return self;
}

- (id)init {
	return [self initWithOption:@""];
}

- (id)initWithDictionary:(NSDictionary *)dict {
	return [self initWithOption:dict[@"parameter"]];
}

- (NSMutableDictionary *)dictionary {
	NSMutableDictionary *dict = [super dictionary];
    dict[@"parameter"] = [networkLocation copy];
	return dict;
}

- (NSString *)description {
	return [NSString stringWithFormat:NSLocalizedString(@"Changing network location to '%@'.", @""),
		networkLocation];
}

- (BOOL)isRequiredNetworkLocationAlreadySet {
	BOOL result = NO;
    
    SCPreferencesRef prefs = SCPreferencesCreate(NULL, CFSTR("ControlPlane"), NULL);
	SCPreferencesLock(prefs, true);
    
    SCNetworkSetRef currentSet = SCNetworkSetCopyCurrent(prefs);
    if (currentSet) {
        NSString *currentNetworkName = (__bridge NSString *)SCNetworkSetGetName(currentSet);
        result = [currentNetworkName isEqualToString:networkLocation];
        CFRelease(currentSet);
    }
    
    SCPreferencesUnlock(prefs);
    CFRelease(prefs);
    
    return result;
}

- (BOOL)execute:(NSString **)errorString {
    if ([self isRequiredNetworkLocationAlreadySet]) {
#ifdef DEBUG_MODE
        NSLog(@"Network location is already set to '%@'", networkLocation);
#endif
        return YES;
    }

    __block NSString *networkSetId = nil;

	NSDictionary *allSets = [[self class] getAllSets];
    [allSets enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *subdict, BOOL *stop) {
        if ([subdict isKindOfClass:[NSDictionary class]]) {
            id userDefinedName = subdict[(NSString *)kSCPropUserDefinedName];
            if ( (userDefinedName != nil)
                && [userDefinedName isKindOfClass:[NSString class]]
                && [userDefinedName isEqualToString:networkLocation] )
            {
                networkSetId = key;
                *stop = YES;
            }
        }
    }];

	if (!networkSetId) {
		NSString *format = NSLocalizedString(@"No network location named \"%@\" exists!", @"Action error message");
        *errorString = [NSString stringWithFormat:format, networkLocation];
		return NO;
	}

    // Using SCPreferences* to change the location requires a setuid binary,
	// so we just execute /usr/sbin/scselect to do the heavy lifting.
	NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/sbin/scselect" arguments:@[ networkSetId ]];
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
	NSDictionary *allSets = [[self class] getAllSets];
    NSMutableArray *networkLocationNames = [NSMutableArray arrayWithCapacity:[allSets count]];

    [allSets enumerateKeysAndObjectsUsingBlock:^(id key, NSDictionary *set, BOOL *stop) {
        if ([set isKindOfClass:[NSDictionary class]]) {
            id userDefinedName = set[(NSString *)kSCPropUserDefinedName];
            if ((userDefinedName != nil) && [userDefinedName isKindOfClass:[NSString class]]) {
                [networkLocationNames addObject:userDefinedName];
            }
        }
    }];
	[networkLocationNames sortUsingSelector:@selector(localizedCompare:)];

	NSMutableArray *opts = [NSMutableArray arrayWithCapacity:[networkLocationNames count]];
	for (NSString *loc in networkLocationNames) {
		[opts addObject:@{ @"option": loc, @"description": loc }];
    }

	return opts;
}

+ (NSString *)friendlyName {
    return NSLocalizedString(@"Network Location", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Networking", @"");
}

@end
