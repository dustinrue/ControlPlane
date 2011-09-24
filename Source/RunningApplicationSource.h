//
//	PowerSource.h
//	ControlPlane
//
//	Created by David Jennes on 23/09/11.
//	Copyright 2011. All rights reserved.
//

#import "CallbackSource.h"

@interface RunningApplicationSource : CallbackSource {
	NSArray *m_applications;
}

@property (readwrite, copy) NSArray *applications;

@end
