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
    
    // before we toggle (especially on) we need to know which sharing types are enabled. 
    // We check here, though we're only interested in SMB and AFP, not FTP which exists
    // on pre-Lion systems
    NSDictionary *fileSharingConfig = [NSDictionary dictionaryWithContentsOfFile:@"/Library/Preferences/com.apple.filesharingui.plist"];
    
    BOOL afpIsEnabled = [[fileSharingConfig valueForKey:@"AFPEnabled"] boolValue];
    BOOL smbdIsEnabled = [[fileSharingConfig valueForKey:@"SMBEnabled"] boolValue];
    
    BOOL afpStatusFailed = NO;
    BOOL smbdStatusFailed = NO;
        
    if (afpIsEnabled && turnOn) {
        DSLog(@"enabling AFP file sharing services");
        if (![self helperToolPerformAction:@kCPHelperToolEnableFileSharingCommand withParameter:@kCPHelperToolAFPSericeName]) 
            afpStatusFailed = YES;
    }
    else if (afpIsEnabled && !turnOn) {
        DSLog(@"disabling AFP file sharing services");
        if (![self helperToolPerformAction:@kCPHelperToolDisableFileSharingCommand withParameter:@kCPHelperToolAFPSericeName]) 
            afpStatusFailed = YES;
    }
    

        
    if (smbdIsEnabled && turnOn) {
        DSLog(@"enabling SMBD file sharing services");
        if (![self helperToolPerformAction:@kCPHelperToolEnableFileSharingCommand withParameter:@kCPHelperToolSMBDServiceName]) {
            smbdStatusFailed = YES;
        }
    }
    else if (smbdIsEnabled && !turnOn) {
        DSLog(@"disabling SMBD file sharing services");
        if (![self helperToolPerformAction:@kCPHelperToolDisableFileSharingCommand withParameter:@kCPHelperToolSMBDServiceName])
            smbdStatusFailed = YES;
            
    }
    
    
    
	if (afpStatusFailed || smbdStatusFailed) {
		if (turnOn)
			*errorString = NSLocalizedString(@"Failed enabling File Sharing.", @"");
		else
			*errorString = NSLocalizedString(@"Failed disabling File Sharing.", @"Act of turning off or disabling File Sharing failed");
	}

    
	return (!afpStatusFailed && !smbdStatusFailed);
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
