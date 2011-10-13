//
//  OpenAction.m
//  ControlPlane
//
//  Created by David Symonds on 3/04/07.
//

#import "OpenAction.h"


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

	if (![[NSWorkspace sharedWorkspace] getInfoForFile:path application:&app type:&fileType]) {
		*errorString = [NSString stringWithFormat:NSLocalizedString(@"Failed opening '%@'.", @""), path];
		return NO;
	}

#ifdef DEBUG
	NSLog(@"[%@]: Type: '%@'.", [self class], fileType);
#endif

	if ([[fileType uppercaseString] isEqualToString:@"SCPT"]) {
		NSArray *args = [NSArray arrayWithObject:path];
		NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/osascript" arguments:args];
		[task waitUntilExit];
		if ([task terminationStatus] == 0)
			return YES;
	} else {
		// Fallback
		if ([[NSWorkspace sharedWorkspace] openFile:path])
			return YES;
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
	self = [self init];
	[path release];
	path = [file copy];
	return self;
}

@end
