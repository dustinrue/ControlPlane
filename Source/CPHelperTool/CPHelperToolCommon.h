//
//  CPHelperToolCommon.h
//  ControlPlane
//
//  Created by Dustin Rue on 3/9/11.
//  Copyright 2011. All rights reserved.
//

#ifndef ControlPlane_CPHelperToolCommon_h
#define ControlPlane_CPHelperToolCommon_h

#import "BetterAuthorizationSampleLib.h"

// Helper tool version
#define kCPHelperToolVersionNumber			16

// Commands
#define kCPHelperToolGetVersionCommand		"GetVersion"
#define kCPHelperToolGetVersionResponse		"Version"

#define kCPHelperToolEnableTMCommand		"EnableTM"
#define kCPHelperToolDisableTMCommand		"DisableTM"
#define kCPHelperToolStartBackupTMCommand	"StartBackupTM"
#define kCPHelperToolStopBackupTMCommand	"StopBackupTM"

#define kCPHelperToolEnableISCommand        "EnableIS"
#define kCPHelperToolDisableISCommand       "DisableIS"

#define kCPHelperToolEnableFirewallCommand  "EnableFirewall"
#define kCPHelperToolDisableFirewallCommand "DisableFirewall"

// Rights
#define kCPHelperToolToggleTMRightName		"com.dustinrue.ControlPlane.ToggleTM"
#define kCPHelperToolRunBackupTMRightName	"com.dustinrue.ControlPlane.RunBackupTM"
#define kCPHelperToolToggleISRightName      "com.dustinrue.ControlPlane.ToggleIS"
#define kCPHelperToolToggleFWRightName      "com.dustinrue.ControlPlane.ToggleFW"

// Commands array (keep in sync!)
extern const BASCommandSpec kCPHelperToolCommandSet[];

#endif
