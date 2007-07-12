//
//  FireWireEvidenceSource.m
//  MarcoPolo
//
//  Created by David Symonds on 29/03/07.
//

#import <IOKit/IOCFPlugIn.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/firewire/IOFireWireLib.h>

#import "DB.h"
#import "FireWireEvidenceSource.h"
#import "MPController.h"


#pragma mark C callbacks

static void devAdded(void *ref, io_iterator_t iterator)
{
	FireWireEvidenceSource *mon = (FireWireEvidenceSource *) ref;
	[mon devAdded:iterator];
}

static void devRemoved(void *ref, io_iterator_t iterator)
{
	FireWireEvidenceSource *mon = (FireWireEvidenceSource *) ref;
	[mon devRemoved:iterator];
}


@implementation FireWireEvidenceSource


- (id)init
{
	if (!(self = [super init]))
		return nil;

	lock = [[NSLock alloc] init];
	devices = [[NSMutableArray alloc] init];

	return self;
}

- (void)dealloc
{
	[lock dealloc];
	[devices dealloc];

	[super dealloc];
}

#pragma mark Utility methods

// Returns GUID, or nil on failure/error.
+ (NSNumber *)guidForDevice:(io_service_t *)device
{
	CFNumberRef guid = (CFNumberRef) IORegistryEntryCreateCFProperty(*device, CFSTR("GUID"),
									 kCFAllocatorDefault, 0);
	if (guid) {
		UInt64 res;
		CFNumberGetValue(guid, kCFNumberLongLongType, &res);	// XXX: lose precision with signedness?
		CFRelease(guid);
		return [NSNumber numberWithUnsignedLongLong:res];
	}

	return nil;
}

// Returns name, or nil on failure/error.
+ (NSString *)nameForDevice:(io_service_t *)device
{
	CFStringRef name = (CFStringRef) IORegistryEntryCreateCFProperty(*device, CFSTR("FireWire Product Name"),
									 kCFAllocatorDefault, 0);
	if (name) {
		NSString *str = [NSString stringWithString:(NSString *) name];
		CFRelease(name);
		return str;
	}

	return nil;
}

// Returns vendor name, or nil on failure/error.
+ (NSString *)vendorForDevice:(io_service_t *)device
{
	CFStringRef name = (CFStringRef) IORegistryEntryCreateCFProperty(*device, CFSTR("FireWire Vendor Name"),
									 kCFAllocatorDefault, 0);
	if (name) {
		NSString *str = [NSString stringWithString:(NSString *) name];
		CFRelease(name);
		return str;
	}

	return nil;
}

#pragma mark Internal callbacks

- (void)devAdded:(io_iterator_t)iterator
{
	io_service_t device;
	int cnt = -1;
	while ((device = IOIteratorNext(iterator))) {
		++cnt;

		// Get device details
		NSNumber *guid = [[self class] guidForDevice:&device];
		if (!guid) {
			NSLog(@"FireWire >> failed getting GUID.\n", cnt);
			goto end_of_device_handling;
		}

		// Try to get device name
		NSString *device_name = [[self class] nameForDevice:&device];
		if (!device_name)
			device_name = NSLocalizedString(@"(Unnamed device)", @"String for unnamed devices");

		// Lookup vendor name
		NSString *vendor_name = [[self class] vendorForDevice:&device];

		NSMutableDictionary *dev_dict = [NSMutableDictionary dictionary];
		[dev_dict setValue:guid forKey:@"guid"];
		[dev_dict setValue:device_name forKey:@"device_name"];
		if (vendor_name)
			[dev_dict setValue:vendor_name forKey:@"vendor_name"];

		// Add to list if we can
		[lock lock];
		NSEnumerator *en = [devices objectEnumerator];
		NSDictionary *elt;
		while (elt = [en nextObject]) {
			if ([[elt objectForKey:@"guid"] isEqualToNumber:guid]) {
				// Already know about this device
				goto end_of_search;
			}
		}
#ifdef DEBUG_MODE
		//NSLog(@"FireWire >> [%d] Adding %@\n", cnt, dev_dict);
#endif
		[devices addObject:dev_dict];
		[self setDataCollected:YES];
end_of_search:
		[lock unlock];

end_of_device_handling:
		IOObjectRelease(device);
	}
}

- (void)enumerateAll
{
	kern_return_t kr;
	io_iterator_t iterator = 0;

	// Create matching dictionary for I/O Kit enumeration
	CFMutableDictionaryRef matchDict = IOServiceMatching("IOFireWireDevice");
	kr = IOServiceGetMatchingServices(kIOMasterPortDefault, matchDict, &iterator);

	[lock lock];
	[devices removeAllObjects];
	[lock unlock];
	[self devAdded:iterator];
	[self setDataCollected:[devices count] > 0];

	IOObjectRelease(iterator);
}

- (void)devRemoved:(io_iterator_t)iterator
{
	io_service_t device;
	while ((device = IOIteratorNext(iterator)))
		IOObjectRelease(device);
	[self enumerateAll];
}

#pragma mark Update stuff

- (void)doFullUpdate
{
	[self enumerateAll];		// be on the safe side
#ifdef DEBUG_MODE
	NSLog(@"%@ >> found %d devices\n", [self class], [devices count]);
#endif
}

- (void)start
{
	if (running)
		return;

	notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
	runLoopSource = IONotificationPortGetRunLoopSource(notificationPort);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);

	CFDictionaryRef matchDict = IOServiceMatching("IOFireWireDevice");
	matchDict = CFRetain(matchDict);	// we use it twice

	IOServiceAddMatchingNotification(notificationPort, kIOMatchedNotification,
					 matchDict, devAdded, (void *) self,
					 &addedIterator);
	IOServiceAddMatchingNotification(notificationPort, kIOTerminatedNotification,
					 matchDict, devRemoved, (void *) self,
					 &removedIterator);

	// Prime notifications
	[self devAdded:addedIterator];
	[self devRemoved:removedIterator];

	// Initial scan
	[self enumerateAll];

	// TODO: we will need to periodically do a full enumeration! (NSTimer, et al)

	running = YES;
}

- (void)stop
{
	if (!running)
		return;

	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
	IONotificationPortDestroy(notificationPort);
	IOObjectRelease(addedIterator);
	IOObjectRelease(removedIterator);

	[lock lock];
	[devices removeAllObjects];
	[self setDataCollected:NO];
	[lock unlock];

	running = NO;
}

- (NSString *)name
{
	return @"FireWire";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	BOOL match = NO;

	NSString *str_guid = [rule objectForKey:@"parameter"];

	[lock lock];
	NSEnumerator *en = [devices objectEnumerator];
	NSDictionary *dev;
	while ((dev = [en nextObject])) {
		if ([[[dev objectForKey:@"guid"] stringValue] isEqualToString:str_guid]) {
			match = YES;
			break;
		}
	}
	[lock unlock];

	return match;
}

- (NSArray *)getDevices
{
	NSArray *arr;

	[lock lock];
	arr = [NSArray arrayWithArray:devices];
	[lock unlock];

	return arr;
}

- (NSArray *)getSuggestions
{
	NSMutableArray *arr = [NSMutableArray array];

	[lock lock];
	NSEnumerator *en = [devices objectEnumerator];
	NSDictionary *dev;
	while ((dev = [en nextObject])) {
		NSString *param = [[dev valueForKey:@"guid"] stringValue];
		NSString *vendor = [dev valueForKey:@"vendor_name"];
		if (!vendor)
			vendor = @"?";
		NSString *desc = [NSString stringWithFormat:@"%@ [%@]",
			[dev valueForKey:@"device_name"], vendor];
		[arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			@"FireWire", @"type",
			param, @"parameter",
			desc, @"description", nil]];
	}
	[lock unlock];

	return arr;
}

@end
