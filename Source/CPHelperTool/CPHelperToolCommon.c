//
//	CPHelperToolCommon.c
//	ControlPlane
//
//	Created by Dustin Rue on 3/9/11.
//	Copyright 2011. All rights reserved.
//

#import "CPHelperToolCommon.h"
#import "BetterAuthorizationLib.h"

const BASCommandSpec kCPHelperToolCommandSet[] = {
	{	kCPHelperToolGetVersionCommand,		// commandName
		NULL,								// rightName
		NULL,								// rightDefaultRule
		NULL,								// rightDescriptionKey
		NULL								// userData
	},
	{	kCPHelperToolSetEnabledFWCommand,
		kCPHelperToolFireWallRightName,
		"allow",
		"SetEnabledFW",
		NULL
	},
	{	kCPHelperToolSetEnabledISCommand,
		kCPHelperToolInternetSharingRightName,
		"allow",
		"SetEnabledIS",
		NULL
	},
	{	kCPHelperToolSetEnabledTMCommand,
		kCPHelperToolTimeMachineRightName,
		"allow",
		"SetEnabledTM",
		NULL
	},
	{	kCPHelperToolControlBackupTMCommand,
		kCPHelperToolTimeMachineRightName,
		"allow",
		"ControlBackupTM",
		NULL
	},
	{	kCPHelperToolSetDisplaySleepTimeCommand,
		kCPHelperToolSleepTimeRightName,
		"allow",
		"SetMonitorSleepTime",
		NULL
	},
	{	NULL,
		NULL,
		NULL,
		NULL,
		NULL
	}
};
