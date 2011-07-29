//
//  BluetoothEvidenceSource.h
//  MarcoPolo
//
//  Created by David Symonds on 29/03/07.
//

#import <Cocoa/Cocoa.h>
#import <IOBluetooth/objc/IOBluetoothDevice.h>
#import <IOBluetooth/objc/IOBluetoothDeviceInquiry.h>
#import <IOBluetooth/objc/IOBluetoothHostController.h>
#import "GenericEvidenceSource.h"


@interface BluetoothEvidenceSource : GenericEvidenceSource {
	NSLock *lock;
	NSMutableArray *devices;
	IOBluetoothDeviceInquiry *inq;
	IOBluetoothUserNotification *notf;
	NSTimer *holdTimer, *cleanupTimer;
    IOBluetoothHostController *btHostController;
}

- (id)init;
- (void)dealloc;

- (void)start;
- (void)stop;

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
