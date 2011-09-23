//
//	PowerSource.h
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import "CallbackSource.h"

typedef enum {
	kPowerBattery,
	kPowerAC,
	kPowerUnknown
} PowerStatus;

@interface PowerSource : CallbackSource {
	PowerStatus m_status;
	CFRunLoopSourceRef m_runLoopSource;
}

@property (readwrite, assign) PowerStatus status;

@end
