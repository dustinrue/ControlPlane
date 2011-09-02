//
//  BluetoothEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 29/03/07.
//  Modified by Dustin Rue on 8/5/2011.
//

#import <Cocoa/Cocoa.h>
#import <IOBluetooth/objc/IOBluetoothDevice.h>
#import <IOBluetooth/objc/IOBluetoothDeviceInquiry.h>

#import "GenericEvidenceSource.h"


@interface BluetoothEvidenceSource : GenericEvidenceSource {
	NSLock *lock;
	NSMutableArray *devices;
	IOBluetoothDeviceInquiry *inq;
	IOBluetoothUserNotification *notf;
    BOOL kIOErrorSet;
    BOOL inquiryStatus;
    BOOL registeredForNotifications;
    int timerCounter;

	NSTimer *holdTimer, *cleanupTimer, *registerForNotificationsTimer;


}

- (id)init;
- (void)dealloc;

- (void)start;
- (void)stop;

// DeviceInquiry control
- (void) startInquiry;
- (void) stopInquiry;
@property (readwrite) BOOL inquiryStatus;
@property (readwrite) BOOL kIOErrorSet;


// Device Connection Notification control
- (void) registerForConnectionNotifications;
- (void) unregisterForConnectionNotifications;
@property (readwrite) BOOL registeredForNotifications;


- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

// IOBluetoothDeviceInquiryDelegate
- (void)deviceInquiryDeviceFound:(IOBluetoothDeviceInquiry *)sender
			  device:(IOBluetoothDevice *)device;
- (void)deviceInquiryComplete:(IOBluetoothDeviceInquiry *)sender
			error:(IOReturn)error
		      aborted:(BOOL)aborted;

@end
