//
//	AudioOutputSource.h
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import "CallbackSource.h"

@interface AudioOutputSource : CallbackSource {
	NSUInteger m_deviceID;
	NSUInteger m_source;
}

@property (readwrite, assign) NSUInteger source;

@end
