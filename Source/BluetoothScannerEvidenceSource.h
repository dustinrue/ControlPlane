//
//  BluetoothScannerEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 29/03/07.
//  Modified by Dustin Rue on 11/28/2011.
//

#import "GenericEvidenceSource.h"
#import <IOBluetooth/objc/IOBluetoothDevice.h>
#import <IOBluetooth/objc/IOBluetoothDeviceInquiry.h>


@interface BluetoothScannerEvidenceSource : GenericEvidenceSource {
	NSLock *lock;
	NSMutableArray *devices;
	IOBluetoothDeviceInquiry *inq;

    BOOL kIOErrorSet;
    BOOL inquiryStatus;
    BOOL registeredForNotifications;
    int timerCounter;
    
	NSTimer *holdTimer, *cleanupTimer;
    
    
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
