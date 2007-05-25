//
//  SysConf.h
//  MarcoPolo
//
//  Created by David Symonds on 4/09/06.
//

#import <Cocoa/Cocoa.h>

@interface SysConf : NSObject { }

// Location functions
+ (NSString *)getCurrentLocation;
+ (BOOL)setCurrentLocation:(NSString *)location;
+ (NSArray *)locationsEnumerate;

@end
