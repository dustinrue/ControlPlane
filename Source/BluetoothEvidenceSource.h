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

    NSTimer *registerForNotificationsTimer;
}

- (id)init;
- (void)dealloc;

- (void)start;
- (void)stop;

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

- (void)deviceInquiryDeviceFound:(IOBluetoothDeviceInquiry *)sender
                          device:(IOBluetoothDevice *)device;



@end
