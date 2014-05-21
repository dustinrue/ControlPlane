//
//  CPNotifications.m
//  ControlPlane
//
//  Created by Dustin Rue on 7/27/12.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import "CPNotifications.h"
#import <Growl/Growl.h>

@implementation CPNotifications

+ (void)postUserNotification:(NSString *)title withMessage:(NSString *)message
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"EnableGrowl"]) {
        [CPNotifications postNotification:[title copy] withMessage:[message copy]];
    }
}

+ (void)postNotification:(NSString *)title withMessage:(NSString *)message
{
    // use Notification Center if it is available
    if (NSClassFromString(@"NSUserNotification") != nil) {
        NSUserNotification *notificationMessage = [[NSUserNotification alloc] init];
        
        notificationMessage.title = title;
        notificationMessage.informativeText = message;
        
        NSUserNotificationCenter *unc = [NSUserNotificationCenter defaultUserNotificationCenter];
        
        [unc scheduleNotification:notificationMessage];
    } else {
        // use Growl otherwise
        signed int pri = [title isEqualToString:@"Failure"] ? (1) : (0);
    
        @try {
            [GrowlApplicationBridge notifyWithTitle:title
                                        description:message
                                   notificationName:title
                                           iconData:nil
                                           priority:pri
                                           isSticky:NO
                                       clickContext:nil];
        }
        @catch (NSException *exception) {
            // something went wrong and we're going to simply throw the message away
            NSLog(@"derp %@", exception);
        }
    }
}

@end
