//
//  CPSystemInfo.h
//  ControlPlane
//
//  Created by Dustin Rue on 7/12/13.
//
//

#import <Foundation/Foundation.h>

@interface CPSystemInfo : NSObject

// returns hardware model string (MacBook7,1)
+ (NSString *) getHardwareModel;



// returns true if this is a portable Mac.  Currently a very simple test
// against whether or not the model name contains book in the name.  This should
// match MacBook, MacBookPro and MacBookAir.
+ (BOOL) isPortable;

+ (SInt32) getOSVersion;


@end
