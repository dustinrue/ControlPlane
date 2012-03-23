//
//  MountAction.m
//  ControlPlane
//
//  Created by David Symonds on 9/06/07.
//

#import "MountAction.h"


@implementation MountAction

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
	return [NSString stringWithFormat:NSLocalizedString(@"Mounting '%@'.", @""), path];
}

- (BOOL) execute: (NSString **) errorString {
	FSVolumeRefNum refNum;
	
	// make sure any space characters in the url string are percent-escaped
	NSString *escapedPath = [path stringByAddingPercentEscapesUsingEncoding: NSMacOSRomanStringEncoding];
	NSURL *url = [NSURL URLWithString: escapedPath];
	
	// try to mount
	OSStatus error = FSMountServerVolumeSync((CFURLRef) url, NULL, NULL, NULL, &refNum, 0L);
	
	if (error) {
		NSLog(@"Server %@ reported error %ld", path, (long) error);
		*errorString = NSLocalizedString(@"Couldn't mount that volume!", @"In MountAction");
	}
	
	return (error ? NO : YES);
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for Mount actions is the volume to mount, such as "
				 "\"smb://server/share\" or \"afp://server/share\".", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Mount a volume with address", @"");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Mount", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Finder", @"");
}

@end
