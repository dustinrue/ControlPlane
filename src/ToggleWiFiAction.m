//
//  ToggleWiFiAction.m
//  MarcoPolo
//
//  Created by David Symonds on 2/05/07.
//

#import "Apple80211.h"
#import "ToggleWiFiAction.h"


@implementation ToggleWiFiAction

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
	return NSLocalizedString(@"The parameter for ToggleWiFi actions is either \"1\" "
				 "or \"0\", depending on whether you want your WiFi "
				 "turned on or off.", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Turn WiFi", @"Will be followed by 'on' or 'off'");
}

@end
