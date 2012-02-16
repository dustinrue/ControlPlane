//
//  CPHelperToolCommon.h
//  ControlPlane
//
//  Created by Dustin Rue on 3/9/11.
//  Copyright 2011. All rights reserved.
//

#ifndef ControlPlane_CPHelperToolCommon_h
#define ControlPlane_CPHelperToolCommon_h

#import "BetterAuthorizationLib.h"

// Helper tool version
#define kCPHelperToolVersionNumber				30

// Commands
#define kCPHelperToolGetVersionCommand			"GetVersion"
#define kCPHelperToolGetVersionResponse			"Version"

#define kCPHelperToolSetEnabledFWCommand		"SetEnabledFW"
#define kCPHelperToolSetEnabledISCommand		"SetEnabledIS"
#define kCPHelperToolSetEnabledPSCommand		"SetEnabledPS"
#define kCPHelperToolSetEnabledTMCommand		"SetEnabledTM"
#define kCPHelperToolControlBackupTMCommand		"ControlBackupTM"
#define kCPHelperToolSetDisplaySleepTimeCommand	"SetDisplaySleepTime"

// Rights
#define kCPHelperToolFireWallRightName			"com.dustinrue.ControlPlane.FireWall"
#define kCPHelperToolInternetSharingRightName	"com.dustinrue.ControlPlane.InternetSharing"
#define kCPHelperToolPrinterSharingRightName	"com.dustinrue.ControlPlane.PrinterSharing"
#define kCPHelperToolTimeMachineRightName		"com.dustinrue.ControlPlane.TimeMachine"
#define kCPHelperToolSleepTimeRightName			"com.dustinrue.ControlPlane.SleepTime"

// Commands array (keep in sync!)
extern const BASCommandSpec kCPHelperToolCommandSet[];

#endif
