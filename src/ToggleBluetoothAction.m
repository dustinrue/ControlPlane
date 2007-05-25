//
//  ToggleBluetoothAction.m
//  MarcoPolo
//
//  Created by David Symonds on 1/05/07.
//

#import "ToggleBluetoothAction.h"


@implementation ToggleBluetoothAction

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
		return NSLocalizedString(@"Turning Bluetooth on.", @"");
	else
		return NSLocalizedString(@"Turning Bluetooth off.", @"");
}

// IOBluetooth.framework is not thread-safe, so all IOBluetooth calls need to be done in the main thread.
- (void)setPowerState
{
	IOBluetoothPreferenceSetControllerPowerState(turnOn ? 1 : 0);
	setState = IOBluetoothPreferenceGetControllerPowerState();
}

- (BOOL)execute:(NSString **)errorString
{
	int state = (turnOn ? 1 : 0);

	[self performSelectorOnMainThread:@selector(setPowerState) withObject:nil waitUntilDone:YES];
	if (state != setState) {
		if (turnOn)
			*errorString = NSLocalizedString(@"Failed turning Bluetooth on.", @"");
		else
			*errorString = NSLocalizedString(@"Failed turning Bluetooth off.", @"");
		return NO;
	}

	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for ToggleBluetooth actions is simply either \"on\" "
				 "or \"off\", depending on whether you want your Bluetooth controller's power "
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
	return NSLocalizedString(@"Turn Bluetooth", @"Will be followed by 'on' or 'off'");
}

- (id)initWithOption:(NSString *)option
{
	[self init];
	turnOn = [[self class] stateForString:option];
	return self;
}

@end
