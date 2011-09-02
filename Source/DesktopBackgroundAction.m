//
//  DesktopBackgroundAction.m
//  ControlPlane
//
//  Created by David Symonds on 12/11/07.
//

#import "DesktopBackgroundAction.h"


@implementation DesktopBackgroundAction

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
	return [NSString stringWithFormat:NSLocalizedString(@"Setting desktop background to '%@'.", @""),
		[path lastPathComponent]];
}

- (BOOL)execute:(NSString **)errorString {
	// check if background exists
	if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
		*errorString = [NSString stringWithFormat:NSLocalizedString(@"Failed setting '%@' as desktop background.", @""), path];
		return NO;
	}
	
	// get current screen and options
	NSScreen *screen = [NSScreen mainScreen];
	NSDictionary *options = [[NSWorkspace sharedWorkspace] desktopImageOptionsForScreen: screen];
	NSURL *image = [NSURL fileURLWithPath:path];
	NSError *error;
	
	// set background
	if (![[NSWorkspace sharedWorkspace] setDesktopImageURL:image forScreen:screen options:options error:&error]) {
		*errorString = [NSString stringWithFormat:NSLocalizedString(@"Failed setting '%@' as desktop background.", @""), path];
		return NO;
	}
	
	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for DesktopBackground actions is the full path of the "
				 "image to be set as the background picture.", @"");
}

- (id)initWithFile:(NSString *)file
{
	[self init];
	[path release];
	path = [file copy];
	return self;
}

@end
