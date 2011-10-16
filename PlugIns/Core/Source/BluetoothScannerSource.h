//
//  BluetoothScannerSource.h
//  ControlPlane
//
//  Created by David Jennes on 16/10/11.
//  Copyright (c) 2011. All rights reserved.
//

#import <Plugins/Sources.h>

@class IOBluetoothDeviceInquiry;

extern const struct BSSIntervalsStruct {
	NSTimeInterval scan;
	uint8_t inquiry;
	NSTimeInterval expiry;
	NSTimeInterval cleanup;
} BSSIntervals;

@interface BluetoothScannerSource : CallbackSource<CallbackSourceProtocol> {
	NSDictionary *m_devices;
	NSMutableDictionary *m_expiry;
	NSMutableDictionary *m_foundDevices;
	
	NSTimer *m_cleanupTimer;
	IOBluetoothDeviceInquiry *m_inquiry;
	NSTimer *m_inquiryTimer;
}

@property (readwrite, copy) NSDictionary *devices;

@end
