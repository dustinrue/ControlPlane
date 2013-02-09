//
//  UnmountAction.m
//  ControlPlane
//
//  Created by Mark Wallis on 14/11/07.
//  Updated by Dustin Rue - 08/01/2011
//

#import "UnmountAction.h"



@implementation UnmountAction

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
	return [NSString stringWithFormat:NSLocalizedString(@"Unmounting '%@'.", @""), path];
}

- (BOOL)execute:(NSString **)errorString
{
    NSError *error;
    BOOL success = NO;
    
    // unmount if it exists
    NSURL *pathAsURL = [NSURL fileURLWithPath:path];
    if ([pathAsURL checkResourceIsReachableAndReturnError:&error] == YES) {
        success = [[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtURL:pathAsURL error:&error];
    }
    // try again in case the user only provided the name of the mount instead of the full path
    // we assume it is in /Volumes because a user who knows how to mount something anywhere else
    // will probably realize to provide a full path as well
    else {
        pathAsURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/Volumes/%@", path]];
        if ([pathAsURL checkResourceIsReachableAndReturnError:&error] == YES)
            success = [[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtURL:pathAsURL error:&error];
    }
    
	if (!success) {
		*errorString = [[[NSString alloc] initWithFormat:@"%@: %@", NSLocalizedString(@"Couldn't unmount that volume!", @"In UnmountAction"), [error localizedFailureReason]] autorelease];
        
		return NO;
	}


	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for Unmount actions is the volume name to unmount. "
				 "You can find the volume name in the /Volumes/ folder after a successful mount.", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Unmount a volume with mount location", @"");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Unmount disk/share", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Finder", @"");
}

@end
