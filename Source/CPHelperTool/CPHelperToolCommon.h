//
//  CPHelperToolCommon.h
//  ControlPlane
//
//  Created by Dustin Rue on 9/3/11.
//  Copyright 2011. All rights reserved.
//

#ifndef ControlPlane_CPHelperToolCommon_h
#define ControlPlane_CPHelperToolCommon_h

#include "BetterAuthorizationSampleLib.h"


#define kCPHelperToolEnableTMSLCommand      "EnableTMSL"
#define kCPHelperToolEnableTMLionCommand    "EnableTMLion"

#define kCPHelperToolDisableTMSLCommand     "DisableTMSL"
#define kCPHelperToolDisableTMLionCommand   "DisableTMLion"


#define kCPHelperTOOLToggleTMRightName      "com.dustinrue.ControlPlane.ToggleTM"

extern const BASCommandSpec kCPHelperToolCommandSet[];

#endif
