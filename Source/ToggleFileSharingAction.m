//
//  ToggleFileSharingAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 3/17/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "ToggleFileSharingAction.h"
#import "Action+HelperTool.h"
#import "DSLogger.h"

@implementation ToggleFileSharingAction

- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Enabling File Sharing.", @"Act of turning on or enabling File Sharing is being performed");
	else
		return NSLocalizedString(@"Disabling File Sharing.", @"Act of turning off or disabling File Sharing is being performed");
}

- (BOOL) execute: (NSString **) errorString {
    
    BOOL afpStatusFailed = NO;
    BOOL smbdStatusFailed = NO;
    
    // the overrides file for launchd specifies what items are "Disabled"
    // so if the value is true, then the item is disabled, false for enabled
    // we assume that the items are disabled by default in case
    // the helper tool simply fails to get the actual state
    BOOL afpIsDisabled = YES;
    BOOL smbdIsDisabled = YES;
    
    // the response from the helper tool is a CFDictionaryRef
    // and we need to convert it later
    NSDictionary *statusDict = nil;
    
    
    // before we toggle (especially on) we need to know which sharing types are enabled. 
    // We check here, though we're only interested in SMB and AFP, not FTP which exists
    // on pre-Lion systems
    
    // helpertool returns 1 for fail 0 for success
    if ([self helperToolPerformAction:@kCPHelperToolGetFileSharingConfigCommand withParameter:@kCPHelperToolAFPSericeName]) {
        DSLog(@"CPHelperTool failed to get AFP status");
        afpStatusFailed = YES;
    }
    else {
        statusDict = (__bridge NSDictionary*) helperToolResponse;
        afpIsDisabled = [[statusDict valueForKey:@"sharingStatus"] boolValue];
        
        if (!afpIsDisabled && turnOn) {
            DSLog(@"enabling AFP file sharing services");
            if ([self helperToolPerformAction:@kCPHelperToolEnableFileSharingCommand withParameter:@kCPHelperToolAFPSericeName]) 
                afpStatusFailed = YES;
        }
        else if (!afpIsDisabled && !turnOn) {
            DSLog(@"disabling AFP file sharing services");
            if ([self helperToolPerformAction:@kCPHelperToolDisableFileSharingCommand withParameter:@kCPHelperToolAFPSericeName]) 
                afpStatusFailed = YES;
        }
    }
    
    
    if ([self helperToolPerformAction:@kCPHelperToolGetFileSharingConfigCommand withParameter:@kCPHelperToolSMBDServiceName]) {
        DSLog(@"CPHelperTool failed to get smbd status");
    }
    else {
        statusDict = (__bridge NSDictionary *) helperToolResponse;
        smbdIsDisabled = [[statusDict valueForKey:@"sharingStatus"] boolValue];
        
        if (!smbdIsDisabled && turnOn) {
            DSLog(@"enabling SMBD file sharing services");
            if ([self helperToolPerformAction:@kCPHelperToolEnableFileSharingCommand withParameter:@kCPHelperToolSMBDServiceName]) {
                smbdStatusFailed = YES;
            }
        }
        else if (!smbdIsDisabled && !turnOn) {
            DSLog(@"disabling SMBD file sharing services");
            if ([self helperToolPerformAction:@kCPHelperToolDisableFileSharingCommand withParameter:@kCPHelperToolSMBDServiceName])
                smbdStatusFailed = YES;
                
        }
    }
    
    
	if (afpStatusFailed || smbdStatusFailed) {
		if (turnOn)
			*errorString = NSLocalizedString(@"Failed enabling File Sharing.", @"");
		else
			*errorString = NSLocalizedString(@"Failed disabling File Sharing.", @"Act of turning off or disabling File Sharing failed");
	}


    
	return afpStatusFailed & smbdStatusFailed;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for ToggleFileSharing actions is either \"1\" "
                             "or \"0\", depending on whether you want File Sharing "
                             "turned on or off.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Set File Sharing", @"Will be followed by 'on' or 'off'");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Toggle File Sharing", @"");
}


@end
