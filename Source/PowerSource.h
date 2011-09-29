//
//	PowerSource.h
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import "CallbackSource.h"

typedef enum {
	kDisplayOn = 0,
	kDisplayDimmed = 1,
	kDisplayOff = 2
} eDisplayState;

typedef enum {
	kPowerError = 0,
	kPowerBattery = 1,
	kPowerAC = 2
} ePowerSource;

@interface PowerSource : CallbackSource {
	eDisplayState m_displayState;
	ePowerSource m_powerSource;
	
	CFRunLoopSourceRef m_runLoopDisplay;
	CFRunLoopSourceRef m_runLoopSource;
}

@property (readwrite, assign) eDisplayState displayState;
@property (readwrite, assign) ePowerSource powerSource;

@end
