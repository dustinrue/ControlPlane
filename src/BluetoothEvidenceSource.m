//
//  BluetoothEvidenceSource.m
//  MarcoPolo
//
//  Created by David Symonds on 29/03/07.
//

#import <IOBluetooth/objc/IOBluetoothDevice.h>
#import <IOBluetooth/objc/IOBluetoothDeviceInquiry.h>

#import "BluetoothEvidenceSource.h"
#import "DB.h"

#define EXPIRY_INTERVAL		((NSTimeInterval) 60)


@implementation BluetoothEvidenceSource

- (id)init
{
	if (!(self = [super init]))
		return nil;

	lock = [[NSLock alloc] init];
	devices = [[NSMutableArray alloc] init];

	inq = [[IOBluetoothDeviceInquiry inquiryWithDelegate:self] retain];
	[inq setUpdateNewDeviceNames:TRUE];

	return self;
}

- (void)dealloc
{
	[super blockOnThread];

	[lock dealloc];
	[devices dealloc];
	[inq release];

	[super dealloc];
}

- (void)goingToSleep:(id)arg
{
	[inq stop];
	[super goingToSleep:arg];
}

- (void)wakeFromSleep:(id)arg
{
	[super wakeFromSleep:arg];
	if (sourceEnabled && IOBluetoothPreferenceGetControllerPowerState())
		[inq start];
}

// Returns a string (set to auto-release), or nil.
+ (NSString *)vendorByMAC:(NSString *)mac
{
	NSDictionary *ouiDb = [DB sharedOUIDB];
	NSString *oui = [[mac substringToIndex:8] lowercaseString];
	NSString *name = [ouiDb valueForKey:oui];

	return name;
}

- (void)doUpdateForReal
{
	if (!sourceEnabled || !IOBluetoothPreferenceGetControllerPowerState()) {
		[inq stop];
		[lock lock];
		[devices removeAllObjects];
		[self setDataCollected:NO];
		[lock unlock];
		return;
	}

	// Go through list and remove all expired devices
	[lock lock];
	NSEnumerator *en = [devices objectEnumerator];
	NSDictionary *dev;
	NSMutableIndexSet *index = [NSMutableIndexSet indexSet];
	unsigned int idx = 0;
	while ((dev = [en nextObject])) {
		if ([[dev valueForKey:@"expires"] timeIntervalSinceNow] < 0)
			[index addIndex:idx];
		++idx;
	}
	[devices removeObjectsAtIndexes:index];
	[lock unlock];

#ifdef DEBUG_MODE
	NSLog(@"%@ >> know of %d device(s)", [self class], [devices count]);
	//NSLog(@"%@ >> know about %d paired device(s), too", [self class], [[IOBluetoothDevice pairedDevices] count]);
#endif

	// Start/restart inquiry if needed
	IOReturn rc = [inq start];
#ifdef DEBUG_MODE
	if ((rc != kIOReturnSuccess) && (rc != kIOReturnBusy))
		NSLog(@"%@ >> -[inq start] returned 0x%x!", [self class], rc);
#endif
}

- (void)doUpdate
{
	// Silly Apple made the IOBluetooth framework non-thread-safe, and require all
	// Bluetooth calls to be made from the main thread
	[self performSelectorOnMainThread:@selector(doUpdateForReal) withObject:nil waitUntilDone:YES];
}

- (NSString *)name
{
	return @"Bluetooth";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	BOOL match = NO;

	[lock lock];
	NSEnumerator *en = [devices objectEnumerator];
	NSDictionary *dev;
	NSString *mac = [rule objectForKey:@"parameter"];
	while ((dev = [en nextObject])) {
		if ([[dev valueForKey:@"mac"] isEqualToString:mac]) {
			match = YES;
			break;
		}
	}
	[lock unlock];

	return match;
}

#define INCLUDE_PAIRED_DEVICES

- (NSArray *)getSuggestions
{
	NSMutableArray *arr = [NSMutableArray arrayWithCapacity:[devices count]];
#ifdef INCLUDE_PAIRED_DEVICES
	NSMutableArray *mac_array = [NSMutableArray arrayWithCapacity:[devices count]];
#endif

	[lock lock];
	NSEnumerator *en = [devices objectEnumerator];
	NSDictionary *dev;
	while ((dev = [en nextObject])) {
		NSString *name = [dev valueForKey:@"device_name"];
		if (!name)
			name = NSLocalizedString(@"(Unnamed device)", @"String for unnamed devices");
		NSString *vendor = [dev valueForKey:@"vendor_name"];
		if (!vendor)
			vendor = @"?";

		NSString *desc = [NSString stringWithFormat:@"%@ [%@]", name, vendor];
		[arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			@"Bluetooth", @"type",
			[dev valueForKey:@"mac"], @"parameter",
			desc, @"description", nil]];
#ifdef INCLUDE_PAIRED_DEVICES
		[mac_array addObject:[dev valueForKey:@"mac"]];
#endif
	}
	[lock unlock];

#ifdef INCLUDE_PAIRED_DEVICES
	// Add paired devices manually
	NSArray *paired_devices = [IOBluetoothDevice pairedDevices];
	// WARNING: Handle [IOBluetoothDevice pairedDevices] brokenness -- it can return nil!
	if (!paired_devices)
		paired_devices = [NSArray array];

	en = [paired_devices objectEnumerator];
	IOBluetoothDevice *device;
	while ((device = [en nextObject])) {
		NSString *mac = [[[device getAddressString] copy] autorelease];
		if ([mac_array containsObject:mac])
			continue;
		NSString *name = [[[device getName] copy] autorelease];
		NSString *vendor = [[self class] vendorByMAC:mac];
		if (!vendor)
			vendor = @"?";

		NSString *desc = [NSString stringWithFormat:@"%@ [%@]", name, vendor];
		[arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			@"Bluetooth", @"type",
			mac, @"parameter",
			desc, @"description", nil]];
	}
#endif

	return arr;
}

#pragma mark IOBluetoothDeviceInquiryDelegate methods

- (void)deviceInquiryDeviceFound:(IOBluetoothDeviceInquiry *)sender
			  device:(IOBluetoothDevice *)device
{
	[lock lock];
	NSDate *expires = [NSDate dateWithTimeIntervalSinceNow:EXPIRY_INTERVAL];
	NSEnumerator *en = [devices objectEnumerator];
	NSMutableDictionary *dev;
	while ((dev = [en nextObject])) {
		if ([[dev valueForKey:@"mac"] isEqualToString:[device getAddressString]])
			break;
	}
	if (dev) {
		// Update
		if (![dev valueForKey:@"device_name"])
			[dev setValue:[device getName] forKey:@"device_name"];
		[dev setValue:expires forKey:@"expires"];
	} else {
		// Insert
		NSString *mac = [[[device getAddressString] copy] autorelease];
		NSString *vendor = [[self class] vendorByMAC:mac];

		NSMutableDictionary *dev = [NSMutableDictionary dictionary];
		[dev setValue:mac forKey:@"mac"];
		if ([device getName])
			[dev setValue:[[[device getName] copy] autorelease] forKey:@"device_name"];
		if (vendor)
			[dev setValue:vendor forKey:@"vendor_name"];
		[dev setValue:expires forKey:@"expires"];

		[devices addObject:dev];
	}

	[self setDataCollected:([devices count] > 0)];
	[lock unlock];
}

- (void)deviceInquiryComplete:(IOBluetoothDeviceInquiry *)sender
			error:(IOReturn)error
		      aborted:(BOOL)aborted
{
	if (!sourceEnabled || !IOBluetoothPreferenceGetControllerPowerState()) {
		[lock lock];
		[devices removeAllObjects];
		[self setDataCollected:NO];
		[lock unlock];
		return;
	}

	[sender clearFoundDevices];
	IOReturn rc = [sender start];
#ifdef DEBUG_MODE
	if (rc != kIOReturnSuccess)
		NSLog(@"%@ >> -[inq start] returned 0x%x!", [self class], rc);
#endif
}

@end
