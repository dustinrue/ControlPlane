//
//  ToggleBluetoothAction.m
//  ControlPlane
//
//  Created by David Symonds on 1/05/07.
//

#import "ToggleBluetoothAction.h"
#import <IOBluetooth/objc/IOBluetoothHostController.h>

// requires IOBluetooth.framework
int IOBluetoothPreferenceGetControllerPowerState(void);
void IOBluetoothPreferenceSetControllerPowerState(int);


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

}

- (BOOL)execute:(NSString **)errorString
{
	int state = (turnOn ? 1 : 0);
    int i = 0;
    IOBluetoothHostController *hostController = [IOBluetoothHostController defaultController];
	
    
    // IOBluetoothPreferenceGetControllerPowerState but 
    // there definitely needs to be some amount of time between
    // when the bluetooth controller is enabled or disabled
    // to when you attempt to get the bluetooth conroller's power state
    // ControlPlane attempts to sleep here for 5 seconds to give bluetooth
    // some time to settle.  This check was originally done on the main thread
    // but ControlPlane shouldn't block the main thread for that long
    // so it was moved here, hopefully it doesn't cause harm.
    
    // this and more is "documented" at http://dmaclach.blogspot.com/2010/10/its-dead-jim.html
    // and https://github.com/dustinrue/ControlPlane/issues/11, thanks to David Jennes for finding
    // this tip. This will still cause an error should the bluetooth controller take more than
	// the mentioned 5 seconds to switch, generating a delayed error notification (Growl)

    
    // It's been reported more than once that BT will fail to enable or disable under certain
    // circumstances.  In an attempt to make this a bit more reliable while simulaneously putting
    // in the least amount of effort, ControlPlane simply tries to get the Bluetooth
    // host controller into the desired state a few times.
    
    
    setState = -1;
    
    // try 5 times to change the bluetooth controller state
    while (state != setState && i < 5) {
        [self performSelectorOnMainThread:@selector(setPowerState) withObject:nil waitUntilDone:YES];
        [NSThread sleepForTimeInterval:2];
        setState = hostController.powerState;
        i++;
    }
    
    
	if (state != setState) {
		if (turnOn) 
			*errorString = NSLocalizedString(@"Failed turning Bluetooth on.", @"");
		else
			*errorString = NSLocalizedString(@"Failed turning Bluetooth off.", @"");
		return NO;
	}

    
    NSLog(@"Successfully toggled bluetooth after %d %@", i, (i > 1) ? @"tries":@"try");
	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for ToggleBluetooth actions is either \"1\" "
				 "or \"0\", depending on whether you want your Bluetooth controller's power "
				 "turned on or off.", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Turn Bluetooth", @"Will be followed by 'on' or 'off'");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Toggle Bluetooth", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"System Preferences", @"");
}
@end
