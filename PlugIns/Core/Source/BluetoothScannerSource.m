//
//  BluetoothScannerSource.m
//  ControlPlane
//
//  Created by David Jennes on 16/10/11.
//  Copyright (c) 2011. All rights reserved.
//

#import "BluetoothScannerSource.h"
#import "DB.h"
#import <IOBluetooth/objc/IOBluetoothDevice.h>
#import <IOBluetooth/objc/IOBluetoothDeviceInquiry.h>

@interface BluetoothScannerSource (Private)

- (void) removeExpired;
- (NSDictionary *) deviceToDictionary: (IOBluetoothDevice *) device;
- (NSString *) vendorByMAC: (NSString *) address;

@end

@implementation BluetoothScannerSource

const struct BSSIntervalsStruct BSSIntervals = {
	.scan = 10,		// scan every x seconds
	.inquiry = 6,	// scan for x seconds
	.expiry = 60,	// found devices expire after x seconds
	.cleanup = 10	// clean-up expired devices every x seconds
};

@synthesize devices = m_devices;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.devices = [NSDictionary new];
	m_expiry = [NSMutableDictionary new];
	m_foundDevices = [NSMutableDictionary new];
	
	m_cleanupTimer = nil;
	m_inquiryTimer = nil;
	m_inquiry = [IOBluetoothDeviceInquiry inquiryWithDelegate: self];
	m_inquiry.updateNewDeviceNames = YES;
	m_inquiry.inquiryLength = BSSIntervals.inquiry;
	
	return self;
}

#pragma mark - Required implementation of 'LoopingSource' class

- (NSArray *) observableKeys {
	return [NSArray arrayWithObject: @"devices"];
}

- (void) registerCallback {
	m_cleanupTimer = [NSTimer scheduledTimerWithTimeInterval: BSSIntervals.scan
													  target: self
													selector: @selector(checkData)
													userInfo: nil
													 repeats: YES];
	
	m_cleanupTimer = [NSTimer scheduledTimerWithTimeInterval: BSSIntervals.cleanup
													  target: self
													selector: @selector(removeExpired)
													userInfo: nil
													 repeats: YES];
}

- (void) unregisterCallback {
	[m_inquiry performSelectorOnMainThread: @selector(stop) withObject: nil waitUntilDone: YES];
}

- (void) checkData {
	[m_inquiry performSelectorOnMainThread: @selector(start) withObject: nil waitUntilDone: YES];
}

#pragma mark - Inquiry delegates

- (void) deviceInquiryDeviceFound: (IOBluetoothDeviceInquiry *) sender
						   device: (IOBluetoothDevice *) device {
	
	DLog(@"in deviceInquiryDeviceFound");
	NSString *address = [device getAddressString];
	NSDate *expires = [NSDate dateWithTimeIntervalSinceNow: BSSIntervals.expiry];
	
	@synchronized(m_foundDevices) {
		[m_foundDevices setObject: [self deviceToDictionary: device] forKey: address];
		[m_expiry setObject: expires forKey: address];
		
		// store it
		if (![m_foundDevices isEqualToDictionary: self.devices])
			self.devices = m_foundDevices;
	}
}

- (void) deviceInquiryComplete: (IOBluetoothDeviceInquiry *) sender
						 error: (IOReturn) error
					   aborted: (BOOL) aborted  {
    
    DLog(@"in deviceInquiryComplete with error %x", error);
    
	// error => invalidate data
	if (error != kIOReturnSuccess) {
		DLog(@"Inquiry finished with error: %x", error);
		self.devices = [NSDictionary new];
		return;
	}
	
	// prepare for new search
	[sender clearFoundDevices];
}

- (void) removeExpired {
	@synchronized(m_foundDevices) {
		NSMutableArray *expired = [NSMutableArray new];
		
		// find expired
		for (NSString *address in m_expiry)
			if ([[m_expiry objectForKey: address] timeIntervalSinceNow] < 0)
				[expired addObject: address];
		
		// remove them
		[m_foundDevices removeObjectsForKeys: expired];
		[m_expiry removeObjectsForKeys: expired];
		
		if (expired.count > 0)
			self.devices = m_foundDevices;
	}
}

#pragma mark - Utility methods

- (NSDictionary *) deviceToDictionary: (IOBluetoothDevice *) device {
	NSString *name = device.name;
	
	if (!name)
		name = NSLocalizedString(@"(Unnamed Device)", @"BluetoothSource");
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
			device.name, @"name",
			[self vendorByMAC: [device getAddressString]], @"address",
			nil];
}

- (NSString *) vendorByMAC: (NSString *) address {
	NSDictionary *ouiDb = DB.sharedDB.ouiDB;
	NSString *oui = [address substringToIndex: 8].uppercaseString;
	
	NSString *name = [ouiDb valueForKey:oui];
	if (!name)
		name = @"Unknown";
	DLog(@"Converted %@ to %@", oui, name);
	
	return name;
}

@end
