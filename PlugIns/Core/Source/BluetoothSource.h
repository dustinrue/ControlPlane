//
//  BluetoothSource.h
//  ControlPlane
//
//  Created by David Jennes on 08/10/11.
//  Copyright 2011. All rights reserved.
//

#import "CallbackSource.h"

@interface BluetoothSource : CallbackSource<CallbackSourceProtocol> {
	NSDictionary *m_connectedDevices;
	NSDictionary *m_devices;
}

@property (readwrite, copy) NSDictionary *connectedDevices;
@property (readwrite, copy) NSDictionary *devices;

@end
