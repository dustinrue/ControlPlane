//
//  SystemStateSource.h
//  ControlPlane
//
//  Created by David Jennes on 30/09/11.
//  Copyright 2011. All rights reserved.
//

#import "CallbackSource.h"

typedef enum {
	kSystemNormal = 0,
	kSystemSleep = 1,
	kSystemWake = 2,
	kSystemPowerOff = 3
} eSystemState;

@interface SystemStateSource : CallbackSource<CallbackSourceProtocol> {
	eSystemState m_state;
	BOOL m_allowSleep;
	
	io_connect_t m_rootPort;
	io_object_t m_notifierObject;
	IONotificationPortRef m_notifyPort;
}

@property (readwrite, assign) eSystemState state;
@property (readwrite, assign) BOOL allowSleep;

@end
