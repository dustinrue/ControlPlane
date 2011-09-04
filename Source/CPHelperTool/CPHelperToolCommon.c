//
//  CPHelperToolCommon.c
//  ControlPlane
//
//  Created by Dustin Rue on 9/3/11.
//  Copyright 2011. All rights reserved.
//

#include "CPHelperToolCommon.h"

const BASCommandSpec kCPHelperToolCommandSet[] = {
    {   kCPHelperToolEnableTMSLCommand,         // commandName
        kCPHelperTOOLToggleTMRightName,         // rightName
        "allow",                                // says anyone get acquire this right
        "EnableTMSL",
        NULL
    },
    {   kCPHelperToolDisableTMSLCommand,
        kCPHelperTOOLToggleTMRightName,
        "allow",
        "DisableTMSL",
        NULL
    },
    {   kCPHelperToolEnableTMLionCommand,
        kCPHelperTOOLToggleTMRightName,
        "allow",
        "EnableTMLion",
        NULL
    },
    {   kCPHelperToolDisableTMLionCommand,
        kCPHelperTOOLToggleTMRightName,
        "allow",
        "DisableTMLion",
        NULL
    },
    {   kCPHelperToolStopBackupTM,
        kCPHelperTOOLStopBackupTMRightName,
        "allow",
        "StopBackupTMSL",
        NULL
    },
    {   NULL,
        NULL,
        NULL,
        NULL,
        NULL
    }
};