//
//  CPNotifications.m
//  ControlPlane
//
//  Created by Dustin Rue on 7/27/12.
//
//

#import "CPNotifications.h"


@implementation CPNotifications

+ (void) postNotification:(NSString *)title withMessage:(NSString *)message {
    
    // use Notification Center if it is available
    if (NSClassFromString(@"NSUserNotification")) {
        NSUserNotification *notificationMessage = [[NSUserNotification alloc] init];
        
        notificationMessage.title = title;
        notificationMessage.informativeText = message;
        
        NSUserNotificationCenter *unc = [NSUserNotificationCenter defaultUserNotificationCenter];
        
        [unc scheduleNotification:notificationMessage];
        
        [notificationMessage release];
    }
    else {
        // use Growl otherwise
        signed int pri = 0;
        
        if ([title isEqualToString:@"Failure"])
            pri = 1;
    
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
        }
        

    }
}

@end
