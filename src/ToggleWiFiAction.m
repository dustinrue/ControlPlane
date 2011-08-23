//
//  ToggleWiFiAction.m
//  ControlPlane
//
//  Created by David Symonds on 2/05/07.
//  Ported to CoreWLAN by Shyru - https://github.com/Shyru 8/3/2011
//

#import <CoreWLAN/CoreWLAN.h>
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
    
    NSError *error = nil;
    CWInterface *wif = [CWInterface interface];
    BOOL setPowerSuccess = [wif setPower:turnOn ? YES : NO error:&error];
    if (! setPowerSuccess)
    {
        if (turnOn)
            *errorString = NSLocalizedString(@"Failed turning WiFi on.", @"");
        else
            *errorString = NSLocalizedString(@"Failed turning WiFi off.", @"");
        return NO;
    }
    
    

	// Success
	return YES;
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
