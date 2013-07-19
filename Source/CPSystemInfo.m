//
//  CPSystemInfo.m
//  ControlPlane
//
//  Created by Dustin Rue on 7/12/13.
//
//

#import "CPSystemInfo.h"
#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/sysctl.h>

@implementation CPSystemInfo


+ (NSString *) getHardwareModel {
    static NSString *hwModel = nil;

    if (!hwModel) {
        size_t len = 0;
        if (!sysctlbyname("hw.model", NULL, &len, NULL, 0) && len) {
            char *model = malloc(len * sizeof(char));
            if (!sysctlbyname("hw.model", model, &len, NULL, 0)) {
                hwModel = [[NSString alloc] initWithUTF8String:model];
            }
            free(model);
        }
    }

    return hwModel;
}

+ (BOOL) isPortable {
    return ([[[CPSystemInfo getHardwareModel] lowercaseString] rangeOfString:@"book"].location != NSNotFound);
}

+ (SInt32) getOSVersion {
    // get system version
	SInt32 major = 0, minor = 0;
	Gestalt(gestaltSystemVersionMajor, &major);
    Gestalt(gestaltSystemVersionMinor, &minor);

    // get the version number into a format that
    // matches the availability macros (MAC_OS_X_VERSION_10_8)
    // This will probably break in 10.10 because 10.10 will become
    // 1100 which probably doesn't make sense
    return (major * 10 + minor) * 10;
}

@end
