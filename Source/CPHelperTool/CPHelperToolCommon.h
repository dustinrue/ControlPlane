//
//  CPHelperToolCommon.h
//  ControlPlane
//
//  Created by Dustin Rue on 9/3/11.
//  Copyright 2011. All rights reserved.
//

#ifndef ControlPlane_CPHelperToolCommon_h
#define ControlPlane_CPHelperToolCommon_h

#import "BetterAuthorizationSampleLib.h"

// Helper tool version
#define kCPHelperToolVersionNumber			12

// Commands
#define kCPHelperToolGetVersionCommand		"GetVersion"
#define kCPHelperToolGetVersionResponse		"Version"

#define kCPHelperToolEnableTMCommand		"EnableTM"
#define kCPHelperToolDisableTMCommand		"DisableTM"
#define kCPHelperToolStartBackupTMCommand	"StartBackupTM"
#define kCPHelperToolStopBackupTMCommand	"StopBackupTM"

// Rights
#define kCPHelperToolToggleTMRightName		"com.dustinrue.ControlPlane.ToggleTM"
#define kCPHelperToolRunBackupTMRightName	"com.dustinrue.ControlPlane.RunBackupTM"

// Commands array (keep in sync!)
extern const BASCommandSpec kCPHelperToolCommandSet[];

#endif
