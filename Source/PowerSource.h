//
//	PowerSource.h
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import "CallbackSource.h"

#define kPowerAC @"A/C"
#define kPowerBattery @"Battery"

@interface PowerSource : CallbackSource {
	NSString *m_status;
	CFRunLoopSourceRef m_runLoopSource;
}

@property (readwrite, copy) NSString *status;

@end
