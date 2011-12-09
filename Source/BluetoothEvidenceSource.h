//
//  BluetoothEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 29/03/07.
//  Modified by Dustin Rue on 8/5/2011.
//

#import "GenericEvidenceSource.h"
#import <IOBluetooth/objc/IOBluetoothDevice.h>
#import <IOBluetooth/objc/IOBluetoothDeviceInquiry.h>


@interface BluetoothEvidenceSource : GenericEvidenceSource {
	NSLock *lock;
	NSMutableArray *devices;
    NSMutableArray *devicesRegisteredForDisconnectNotices;
	IOBluetoothDeviceInquiry *inq;
	IOBluetoothUserNotification *notf;
    BOOL kIOErrorSet;
    BOOL inquiryStatus;
    BOOL registeredForNotifications;
    int timerCounter;

    // Paired Bluetooth Devices
    NSTimer *registerForNotificationsTimer;
    
    // Bluetooth Scanner timers
    NSTimer *holdTimer, *cleanupTimer;
}

- (id)init;
- (void)dealloc;

- (void)start;
- (void)stop;

@property (readwrite) BOOL inquiryStatus;
@property (readwrite) BOOL kIOErrorSet;


// Paired Bluetooth Device Connection Notification control
- (void) registerForConnectionNotifications;
- (void) unregisterForConnectionNotifications;
@property (readwrite) BOOL registeredForNotifications;


- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

// Local 
- (void)deviceInquiryDeviceFound:(IOBluetoothDeviceInquiry *)sender
                          device:(IOBluetoothDevice *)device;

// Bluetooth device scanning routines
- (void) startInquiry;
- (void) stopInquiry;
- (void) deviceInquiryComplete:(IOBluetoothDeviceInquiry *)sender
                         error:(IOReturn)error
                       aborted:(BOOL)aborted;

@end
