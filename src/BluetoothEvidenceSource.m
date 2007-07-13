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
	holdTimer = nil;
	cleanupTimer = nil;

	return self;
}

- (void)dealloc
{
	[lock release];
	[devices release];
	[inq release];

	[super dealloc];
}

- (void)start
{
	if (running)
		return;

	if (IOBluetoothPreferenceGetControllerPowerState()) {
#ifdef DEBUG_MODE
		NSLog(@"%s starting inq", __PRETTY_FUNCTION__);
#endif
		[inq performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:YES];
	} else {
		// Various things mysteriously break if we run the inquiry while bluetooth is not on, so we run a
		// timer, waiting for it to turn back on
#ifdef DEBUG_MODE
		NSLog(@"%s starting hold timer", __PRETTY_FUNCTION__);
#endif
		holdTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval) 5
							     target:self
							   selector:@selector(holdTimerPoll:)
							   userInfo:nil
							    repeats:YES];
	}

	cleanupTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval) 10
							target:self
						      selector:@selector(cleanupTimerPoll:)
						      userInfo:nil
						       repeats:YES];

	running = YES;
}

- (void)stop
{
	if (!running)
		return;

	[cleanupTimer invalidate];	// XXX: -[NSTimer invalidate] has to happen from the timer's creation thread

	if (holdTimer) {
#ifdef DEBUG_MODE
		NSLog(@"%s stopping hold timer", __PRETTY_FUNCTION__);
#endif
		[holdTimer invalidate];		// XXX: -[NSTimer invalidate] has to happen from the timer's creation thread
		holdTimer = nil;
	}
#ifdef DEBUG_MODE
	NSLog(@"%s stopping inq", __PRETTY_FUNCTION__);
#endif
	[inq performSelectorOnMainThread:@selector(stop) withObject:nil waitUntilDone:YES];

	[lock lock];
	[devices removeAllObjects];
	[self setDataCollected:NO];
	[lock unlock];

	running = NO;
}

- (void)holdTimerPoll:(NSTimer *)timer
{
	if (!IOBluetoothPreferenceGetControllerPowerState())
		return;

#ifdef DEBUG_MODE
	NSLog(@"%s stopping hold timer, starting inq", __PRETTY_FUNCTION__);
#endif
	[holdTimer invalidate];
	holdTimer = nil;
	[inq performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:YES];
}

// Returns a string (set to auto-release), or nil.
+ (NSString *)vendorByMAC:(NSString *)mac
{
	NSDictionary *ouiDb = [DB sharedOUIDB];
	NSString *oui = [[mac substringToIndex:8] lowercaseString];
	NSString *name = [ouiDb valueForKey:oui];

	return name;
}

- (void)cleanupTimerPoll:(NSTimer *)timer
{
	// Go through list to remove all expired devices
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
	NSLog(@"%@ >> know of %d device(s)%s", [self class], [devices count], holdTimer ? " -- hold timer running" : "");
	//NSLog(@"%@ >> know about %d paired device(s), too", [self class], [[IOBluetoothDevice pairedDevices] count]);
#endif
}

//- (void)doUpdate
//{
//	// Silly Apple made the IOBluetooth framework non-thread-safe, and require all
//	// Bluetooth calls to be made from the main thread
//	[self performSelectorOnMainThread:@selector(doUpdateForReal) withObject:nil waitUntilDone:YES];
//}

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
	// WARNING: Need to handle [IOBluetoothDevice pairedDevices] brokenness -- it can return nil!
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

	[self setDataCollected:[devices count] > 0];
	[lock unlock];
}

- (void)deviceInquiryComplete:(IOBluetoothDeviceInquiry *)sender
			error:(IOReturn)error
		      aborted:(BOOL)aborted
{
	if (error != kIOReturnSuccess) {
#ifdef DEBUG_MODE
		NSLog(@"%s error=0x%08x", __PRETTY_FUNCTION__, error);
#endif
		// Problem! Could just be that Bluetooth has been turned off
		[cleanupTimer invalidate];
		running = NO;
		[self start];
		return;
	}

#ifdef DEBUG_MODE
	NSLog(@"%s succeeded", __PRETTY_FUNCTION__);
#endif
	[sender clearFoundDevices];
#ifdef DEBUG_MODE
	IOReturn rc = [sender start];
	if (rc != kIOReturnSuccess)
		NSLog(@"%@ >> -[inq start] returned 0x%x!", [self class], rc);
#else
	[sender start];
#endif
}

@end
