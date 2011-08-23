//
//  DB.h
//  ControlPlane
//
//  Created by David Symonds on 29/03/07.
//

#import <Cocoa/Cocoa.h>


@interface DB : NSObject {}

+ (NSDictionary *)sharedOUIDB;
+ (NSDictionary *)sharedUSBVendorDB;

@end
