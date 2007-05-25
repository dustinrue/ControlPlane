//
//  OpenAction.m
//  MarcoPolo
//
//  Created by David Symonds on 3/04/07.
//

#import "OpenAction.h"


@implementation OpenAction

- (id)init
{
	if (!(self = [super init]))
		return nil;

	path = @"";

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super init]))
		return nil;

	path = [dict valueForKey:@"parameter"];

	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];

	[dict setObject:path forKey:@"parameter"];

	return dict;
}

- (NSString *)description
{
	return [NSString stringWithFormat:NSLocalizedString(@"Opening '%@'.", @""), path];
}

- (BOOL)execute:(NSString **)errorString
{
	if ([[NSWorkspace sharedWorkspace] openFile:path])
		return YES;

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
	[self init];
	path = file;
	return self;
}

@end
