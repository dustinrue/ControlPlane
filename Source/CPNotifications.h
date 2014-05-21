//
//  CPNotifications.h
//  ControlPlane
//
//  Created by Dustin Rue on 7/27/12.
//
//

#import <Foundation/Foundation.h>

@interface CPNotifications : NSObject

+ (void)postNotification:(NSString *)title withMessage:(NSString *)message;
+ (void)postUserNotification:(NSString *)title withMessage:(NSString *)message;

@end
