//
//  ToggleableAction.m
//  ControlPlane
//
//  Created by David Symonds on 7/06/07.
//

#import "ToggleableAction.h"


@implementation ToggleableAction

- (id)init
{
	if (!(self = [super init]))
		return nil;

	turnOn = NO;

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super initWithDictionary:dict]))
		return nil;

	NSObject *val = [dict valueForKey:@"parameter"];
	if ([val isKindOfClass:[NSNumber class]])
		turnOn = [[dict valueForKey:@"parameter"] boolValue];
	else {
		if ([val isEqual:@"on"] || [val isEqual:@"1"])
			turnOn = YES;
		else
			turnOn = NO;
	}

	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];

	[dict setObject:[NSNumber numberWithBool:turnOn] forKey:@"parameter"];

	return dict;
}

+ (NSArray *)limitedOptions
{
	return [NSArray arrayWithObjects:
		[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"option",
			NSLocalizedString(@"on", @"Used in toggling actions"), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], @"option",
			NSLocalizedString(@"off", @"Used in toggling actions"), @"description", nil],
		nil];
}

- (id)initWithOption:(NSNumber *)option
{
	self = [super init];
	turnOn = [option boolValue];
	return self;
}

@end
