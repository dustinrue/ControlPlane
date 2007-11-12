//
//  DesktopBackgroundAction.m
//  MarcoPolo
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

- (NSString *)pathAsHFSPath
{
	CFURLRef url = CFURLCreateWithFileSystemPath(NULL, (CFStringRef) path, kCFURLPOSIXPathStyle, false);
	NSString *ret = (NSString *) CFURLCopyFileSystemPath(url, kCFURLHFSPathStyle);
	CFRelease(url);

	return ret;
}

- (BOOL)execute:(NSString **)errorString
{
	if (![[NSFileManager defaultManager] fileExistsAtPath:path])
		goto failed_to_set;

	// TODO: properly escape status path
	NSString *script = [NSString stringWithFormat:
		@"tell application \"Finder\"\n"
		"  set desktop picture to \"%@\"\n"
		"end tell\n", [self pathAsHFSPath]];

	if ([self executeAppleScript:script])
		return YES;

failed_to_set:
	*errorString = [NSString stringWithFormat:NSLocalizedString(@"Failed setting '%@' as desktop background.", @""), path];
	return NO;
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
