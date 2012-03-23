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
    // use NSTask to run diskutil to unmount the volume
    NSTask *diskutil;
    diskutil = [[NSTask alloc] init];
    [diskutil setLaunchPath:@"/usr/sbin/diskutil"];
     
    NSArray *diskUtilArguments;
    diskUtilArguments = [NSArray arrayWithObjects:@"unmountDisk",path, nil];
    [diskutil setArguments: diskUtilArguments ];
    
    NSPipe *retValuePipe = [NSPipe pipe];
    [diskutil setStandardError:retValuePipe];
     
    
    [diskutil launch];
    [diskutil waitUntilExit];
    
    NSData *retValueData = [[retValuePipe fileHandleForReading] readDataToEndOfFile];
    

    
    NSString *retValue = [[[NSString alloc] initWithData:retValueData encoding:NSUTF8StringEncoding] autorelease];
    
#ifdef DEBUG_MODE
    NSLog(@"about to get terminationStatus");
#endif
    int status = [diskutil terminationStatus];
    [diskutil release];
    
    
#ifdef DEBUG_MODE
    NSLog(@"task ended with status %d",status);
#endif

	if (status != 0) {
		*errorString = [[[NSString alloc] initWithFormat:@"%@ - %@", NSLocalizedString(@"Couldn't unmount that volume!", @"In UnmountAction"), retValue] autorelease];

        
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
