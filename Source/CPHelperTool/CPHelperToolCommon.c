//
//	CPHelperToolCommon.c
//	ControlPlane
//
//	Created by Dustin Rue on 9/3/11.
//	Copyright 2011. All rights reserved.
//

#include "CPHelperToolCommon.h"

const BASCommandSpec kCPHelperToolCommandSet[] = {
	{	kCPHelperToolGetVersionCommand,		// commandName
		NULL,								// rightName
		NULL,								// rightDefaultRule
		NULL,								// rightDescriptionKey
		NULL								// userData
	},
	{	kCPHelperToolEnableTMCommand,
		kCPHelperToolToggleTMRightName,
		"allow",
		"EnableTM",
		NULL
	},
	{	kCPHelperToolDisableTMCommand,
		kCPHelperToolToggleTMRightName,
		"allow",
		"DisableTM",
		NULL
	},
	{	kCPHelperToolStartBackupTMCommand,
		kCPHelperToolRunBackupTMRightName,
		"allow",
		"StartBackupTM",
		NULL
	},
	{	kCPHelperToolStopBackupTMCommand,
		kCPHelperToolRunBackupTMRightName,
		"allow",
		"StopBackupTM",
		NULL
	},
	{	NULL,
		NULL,
		NULL,
		NULL,
		NULL
	}
};