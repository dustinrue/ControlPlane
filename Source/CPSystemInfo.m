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

@end
