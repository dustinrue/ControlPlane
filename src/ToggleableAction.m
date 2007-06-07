//
//  ToggleableAction.m
//  MarcoPolo
//
//  Created by David Symonds on 7/06/07.
//

#import "ToggleableAction.h"


@implementation ToggleableAction

+ (BOOL)stateForString:(NSString *)string
{
	if ([[string lowercaseString] isEqualToString:@"on"])
		return YES;

	return NO;
}

- (id)init
{
	if (!(self = [super init]))
		return nil;

	turnOn = NO;

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super init]))
		return nil;

	turnOn = [[self class] stateForString:[dict valueForKey:@"parameter"]];

	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];

	[dict setObject:(turnOn ? @"on" : @"off") forKey:@"parameter"];

	return dict;
}

+ (NSArray *)limitedOptions
{
	return [NSArray arrayWithObjects:
		[NSDictionary dictionaryWithObjectsAndKeys:@"on", @"option",
			NSLocalizedString(@"on", @"Used in toggling actions"), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:@"off", @"option",
			NSLocalizedString(@"off", @"Used in toggling actions"), @"description", nil],
		nil];
}

- (id)initWithOption:(NSString *)option
{
	[self init];
	turnOn = [[self class] stateForString:option];
	return self;
}

@end
