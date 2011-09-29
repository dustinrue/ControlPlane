//
//	AudioOutputSource.h
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import "CallbackSource.h"
#import <CoreAudio/CoreAudio.h>

@interface AudioOutputSource : CallbackSource {
	AudioDeviceID m_deviceID;
	UInt32 m_source;
}

@property (readwrite, assign) UInt32 source;

@end
