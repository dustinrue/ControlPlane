//
//  OpenAction.m
//  ControlPlane
//
//  Created by David Symonds on 3/04/07.
//  Updated by Dustin Rue on 8/28/2012 
//

#import "OpenAction.h"
#import "DSLogger.h"

@implementation OpenAction

- (id)init
{
	if (!(self = [super init]))
		return nil;

	path = [[NSString alloc] init];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super initWithDictionary:dict]))
		return nil;

	path = [[dict valueForKey:@"parameter"] copy];

	return self;
}

- (void)dealloc
{
	[path release];

	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];

	[dict setObject:[[path copy] autorelease] forKey:@"parameter"];

	return dict;
}

- (NSString *)description
{
	return [NSString stringWithFormat:NSLocalizedString(@"Opening '%@'.", @""), path];
}

- (BOOL)execute:(NSString **)errorString {
	NSString *app, *fileType;
    BOOL success = NO;

	if (![[NSWorkspace sharedWorkspace] getInfoForFile:path application:&app type:&fileType]) {
		*errorString = [NSString stringWithFormat:NSLocalizedString(@"Failed opening '%@'.", @""), path];
		success = NO;
        return success;
        
	}

	if ([[fileType uppercaseString] isEqualToString:@"SCPT"]) {
		NSArray *args = [NSArray arrayWithObject:path];
		NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/osascript" arguments:args];
		[task waitUntilExit];
		if ([task terminationStatus] == 0) {
			success = YES;
            return success;
        }
        
	} else {
		// Fallback
        // DO NOT "open" an app that is already running, it's annoying
        NSBundle *requestedAppBundle = [[NSBundle alloc] initWithPath:path];
        NSString *requestedApplBundleIdentifier = nil;
        
        // if the requestedAppBundle comes back nil then
        // they are either specifying that an actual file (not an app) be
        // opened
        if (requestedAppBundle != nil) {
            requestedApplBundleIdentifier = [requestedAppBundle bundleIdentifier];
            [requestedAppBundle release];
            DSLog(@"%@ is already running", requestedApplBundleIdentifier);
            if ([[NSRunningApplication runningApplicationsWithBundleIdentifier:requestedApplBundleIdentifier] count] > 0) {
                success = YES;
                return success;
            }
        }
    
        // whether it is a file or an app, it needs to get opened here
        if ([[NSWorkspace sharedWorkspace] openFile:path])
            success = YES;

        
        return success;
	}
	
	*errorString = [NSString stringWithFormat:NSLocalizedString(@"Failed opening '%@'.", @""), path];
	return NO;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for Open actions is the full path of the "
				 "object to be opened, such as an application or a document.", @"");
}

- (id)initWithFile:(NSString *)file
{
	self = [super init];
	[path release];
	path = [file copy];
	return self;
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Open File or Application", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Application", @"");
}

@end
