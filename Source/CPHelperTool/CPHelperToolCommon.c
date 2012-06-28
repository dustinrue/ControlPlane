//
//	CPHelperToolCommon.c
//	ControlPlane
//
//	Created by Dustin Rue on 3/9/11.
//	Copyright 2011. All rights reserved.
//

#import "CPHelperToolCommon.h"
#import "BetterAuthorizationSampleLib.h"

const BASCommandSpec kCPHelperToolCommandSet[] = {
    {	kInstallCommandLineToolCommand,         // commandName
        kInstallCommandLineToolRightName,       // rightName
        "default",                              // rightDefaultRule    -- by default, you have to have admin credentials (see the "default" rule in the authorization policy database, currently "/etc/authorization")
        "AuthInstallCommandLineToolPrompt",				// rightDescriptionKey -- key for custom prompt in "Localizable.strings
        NULL                                    // userData
	},
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
    {   kCPHelperToolEnableISCommand,
        kCPHelperToolToggleISRightName,
        "allow",
        "EnableIS",
        NULL
    },
    {   kCPHelperToolDisableISCommand,
        kCPHelperToolToggleISRightName,
        "allow",
        "DisableIS",
        NULL
    },
    {   kCPHelperToolEnableFirewallCommand,
        kCPHelperToolToggleFWRightName,
        "allow",
        "EnableFirewall",
        NULL
    },
    {   kCPHelperToolDisableFirewallCommand,
        kCPHelperToolToggleFWRightName,
        "allow",
        "DisableFirewall",
        NULL
    },
    {   kCPHelperToolSetDisplaySleepTimeCommand,
        kCPHelperToolSetDisplaySleepTimeRightName,
        "allow",
        "SetMonitorSleepTime",
        NULL
    },
    {   kCPHelperToolEnablePrinterSharingCommand,
        kCPHelperToolTogglePrinterSharingRightName,
        "allow",
        "EnablePrinterSharing",
        NULL
    },
    {   kCPHelperToolDisablePrinterSharingCommand,
        kCPHelperToolTogglePrinterSharingRightName,
        "allow",
        "DisablePrinterSharing",
        NULL
    },
    {   kCPHelperToolEnableAFPFileSharingCommand,
        kCPHelperToolFileSharingRightName,
        "allow",
        "EnableAFPFileSharing",
        NULL
    },
    {   kCPHelperToolDisableAFPFileSharingCommand,
        kCPHelperToolFileSharingRightName,
        "allow",
        "DisableAFPFileSharing",
        NULL
    },
    {   kCPHelperToolEnableSMBFileSharingCommand,
        kCPHelperToolFileSharingRightName,
        "allow",
        "EnableSMBFileSharing",
        NULL
    },
    {   kCPHelperToolDisableSMBFileSharingCommand,
        kCPHelperToolFileSharingRightName,
        "allow",
        "DisableSMBFileSharing",
        NULL
    },
    {   kCPHelperToolEnableTFTPCommand,
        kCPHelperToolTFTPRightName,
        "allow",
        "EnableTFTPCommand",
        NULL
    },
    {   kCPHelperToolDisableTFTPCommand,
        kCPHelperToolTFTPRightName,
        "allow",
        "DisableTFTPCommand",
        NULL
    },
    {   kCPHelperToolEnableFTPCommand,
        kCPHelperToolFTPRightName,
        "allow",
        "EnableFTPCommand",
        NULL
    },
    {   kCPHelperToolDisableFTPCommand,
        kCPHelperToolFTPRightName,
        "allow",
        "DisableFTPCommand",
        NULL
    },
    {   kCPHelperToolEnableWebSharingCommand,
        kCPHelperToolWebSharingRightName,
        "allow",
        "EnableWebSharing",
        NULL
    },
    {   kCPHelperToolDisableWebSharingCommand,
        kCPHelperToolWebSharingRightName,
        "allow",
        "DisableWebSharing",
        NULL
    },
    {   kCPHelperToolEnableRemoteLoginCommand,
        kCPHelperToolRemoteLoginRightName,
        "allow",
        "EnableRemoteLogin",
        NULL
    },
    {   kCPHelperToolDisableRemoteLoginCommand,
        kCPHelperToolRemoteLoginRightName,
        "allow",
        "DisableRemoteLogin",
        NULL
    },
	{	NULL,
		NULL,
		NULL,
		NULL,
		NULL
	}
};
