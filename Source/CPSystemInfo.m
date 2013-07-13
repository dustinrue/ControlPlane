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
    size_t len = 0;
    sysctlbyname("hw.model", NULL, &len, NULL, 0);
    if (len) {
        char *model = malloc(len*sizeof(char));
        sysctlbyname("hw.model", model, &len, NULL, 0);
        NSString *hwModel = [NSString stringWithCString:model encoding:NSUTF8StringEncoding];
        free(model);
        
        return hwModel;
    }
    
    return nil;
}

@end
