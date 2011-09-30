//
//  SleepSource.h
//  ControlPlane
//
//  Created by David Jennes on 30/09/11.
//  Copyright 2011. All rights reserved.
//

#import "CallbackSource.h"

typedef enum {
	kSleepNormal = 0,
	kSleepSleep = 1,
	kSleepWake = 2
} eSleepState;

@interface SleepSource : CallbackSource {
	eSleepState m_state;
	BOOL m_allowSleep;
	
	io_connect_t m_rootPort;
	io_object_t m_notifierObject;
	IONotificationPortRef m_notifyPort;
}

@property (readwrite, assign) eSleepState state;
@property (readwrite, assign) BOOL allowSleep;

@end
