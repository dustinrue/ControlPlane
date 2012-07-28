//
//  CPNotifications.h
//  ControlPlane
//
//  Created by Dustin Rue on 7/27/12.
//
//

#import <Foundation/Foundation.h>
#import <Growl/Growl.h>

@interface CPNotifications : NSObject <GrowlApplicationBridgeDelegate>

+ (void) postNotification:(NSString *)title withMessage:(NSString *)message;

@end
