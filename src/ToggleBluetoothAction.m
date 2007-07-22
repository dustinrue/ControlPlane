//
//  ToggleBluetoothAction.m
//  MarcoPolo
//
//  Created by David Symonds on 1/05/07.
//

#import "ToggleBluetoothAction.h"


@implementation ToggleBluetoothAction

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

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Turn Bluetooth", @"Will be followed by 'on' or 'off'");
}

+ (NSArray *)limitedOptions
{
	return [super limitedOptions];
}

@end
