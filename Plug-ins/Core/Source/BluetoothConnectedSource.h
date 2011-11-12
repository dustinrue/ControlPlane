//
//  BluetoothSource.h
//  ControlPlane
//
//  Created by David Jennes on 08/10/11.
//  Copyright 2011. All rights reserved.
//

#import <Plugins/Sources.h>

@class IOBluetoothDeviceInquiry;
@class IOBluetoothUserNotification;

@interface BluetoothConnectedSource : CallbackSource<CallbackSourceProtocol> {
	NSDictionary *m_devices;
	NSMutableArray *m_internalDevices;
	
	IOBluetoothUserNotification *m_notifications;
}

@property (readwrite, copy) NSDictionary *devices;
@property (readonly) NSDictionary *recentDevices;

@end
