//
//  ToggleWiFiAction.m
//  MarcoPolo
//
//  Created by David Symonds on 2/05/07.
//

#import "Apple80211.h"
#import "ToggleWiFiAction.h"


@implementation ToggleWiFiAction

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

- (NSString *)description
{
	if (turnOn)
		return NSLocalizedString(@"Turning WiFi on.", @"");
	else
		return NSLocalizedString(@"Turning WiFi off.", @"");
}

- (BOOL)execute:(NSString **)errorString
{
	WirelessContextPtr wctxt;

	if (!WirelessIsAvailable())
		goto failure;
	if (WirelessAttach(&wctxt, 0) != noErr)
		goto failure;
	if (WirelessSetPower(wctxt, turnOn ? 1 : 0) != noErr) {
		WirelessDetach(wctxt);
		goto failure;
	}
	WirelessDetach(wctxt);

	// Success
	return YES;

failure:
	if (turnOn)
		*errorString = NSLocalizedString(@"Failed turning WiFi on.", @"");
	else
		*errorString = NSLocalizedString(@"Failed turning WiFi off.", @"");
	return NO;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for ToggleWiFi actions is simply either \"on\" "
				 "or \"off\", depending on whether you want your WiFi "
				 "turned on or off.", @"");
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

+ (NSString *)limitedOptionHelpText
{
	return NSLocalizedString(@"Turn WiFi", @"Will be followed by 'on' or 'off'");
}

- (id)initWithOption:(NSString *)option
{
	[self init];
	turnOn = [[self class] stateForString:option];
	return self;
}

@end
