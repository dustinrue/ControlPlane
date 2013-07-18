//
//  USBEvidenceSource.m
//  ControlPlane
//
//  Created by David Symonds on 29/03/07.
//

#import <IOKit/usb/IOUSBLib.h>
#import "DB.h"
#import "USBEvidenceSource.h"


@interface USBEvidenceSource (Private)

- (void)devAdded:(io_iterator_t)iterator;
- (void)devRemoved:(io_iterator_t)iterator;

@end

#pragma mark C callbacks

static void devAdded(void *ref, io_iterator_t iterator)
{
	USBEvidenceSource *mon = (USBEvidenceSource *) ref;
	[mon devAdded:iterator];
}

static void devRemoved(void *ref, io_iterator_t iterator)
{
	USBEvidenceSource *mon = (USBEvidenceSource *) ref;
	[mon devRemoved:iterator];
}

#pragma mark -

@implementation USBEvidenceSource

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
	[lock release];
	[devices release];

	[super dealloc];
}


- (NSString *) description {
    return NSLocalizedString(@"Create rules based on attached USB devices.", @"");
}

#pragma mark Utility methods

// Returns a string, or the vendor_id in hexadecimal.
+ (NSString *)usbVendorById:(UInt16)vendor_id
{
	NSDictionary *vendDb = [DB sharedUSBVendorDB];
	NSString *vid = [NSString stringWithFormat:@"%d", vendor_id];
	NSString *name = [vendDb valueForKey:vid];

	if (name)
		return name;

	return [NSString stringWithFormat:@"0x%04X", vendor_id];
}

// Returns true on success.
+ (BOOL)usbDetailsForDevice:(io_service_t *)device outVendor:(UInt16 *)vendor_id outProduct:(UInt16 *)product_id
{
	IOReturn rc;
	NSMutableDictionary *props;

	rc = IORegistryEntryCreateCFProperties(*device, (CFMutableDictionaryRef *) &props,
					       kCFAllocatorDefault, kNilOptions);
	if ((rc != kIOReturnSuccess) || !props)
		return NO;
	*vendor_id = [[props valueForKey:@"idVendor"] intValue];
	*product_id = [[props valueForKey:@"idProduct"] intValue];
	[props release];

#ifdef DEBUG_MODE
	//NSLog(@"Found info: vendor=%04X, product=%04X", *vendor_id, *product_id);
#endif
	return YES;
}

#pragma mark Internal callbacks

- (void)devAdded:(io_iterator_t)iterator
{
	// Devices that we ignore.
	static const struct {
		UInt16 vendor_id, product_id;
	} internal_devices[] = {
		{ 0x05AC, 0x0217 },		// (Apple) Internal Keyboard/Trackpad
		{ 0x05AC, 0x021A },		// (Apple) Apple Internal Keyboard/Trackpad
		{ 0x05AC, 0x1003 },		// (Apple) Hub in Apple Extended USB Keyboard
		{ 0x05AC, 0x8005 },		// (Apple) UHCI Root Hub Simulation
		{ 0x05AC, 0x8006 },		// (Apple) EHCI Root Hub Simulation
		{ 0x05AC, 0x8205 },		// (Apple) IOUSBWirelessControllerDevice
		{ 0x05AC, 0x8206 },		// (Apple) IOUSBWirelessControllerDevice
		{ 0x05AC, 0x8240 },		// (Apple) IR Receiver
		{ 0x05AC, 0x8501 },		// (Apple) Built-in iSight
	};
	if (paranoid && !iterator)
		NSLog(@"USB devAdded >> passed null io_iterator_t!");


	io_service_t device;
	int cnt = -1;
	while ((device = IOIteratorNext(iterator))) {
		++cnt;

		// Try to get device name
		NSString *device_name = nil;
		io_name_t dev_name;
		kern_return_t rc;
		if ((rc = IORegistryEntryGetName(device, dev_name)) == KERN_SUCCESS)
			device_name = [NSString stringWithUTF8String:dev_name];
		else {
			NSLog(@"IORegistryEntryGetName failed?!? (rc=0x%08x)", rc);
			device_name = NSLocalizedString(@"(Unnamed device)", @"String for unnamed devices");
		}

		// Get USB vendor ID and product ID
		UInt16 vendor_id;
		UInt16 product_id;
		if (paranoid && !device)
			NSLog(@"USB devAdded >> hit null io_service_t!");
		if (![[self class] usbDetailsForDevice:&device outVendor:&vendor_id outProduct:&product_id]) {
			NSLog(@"USB >> failed getting details.");
			IOObjectRelease(device);
			continue;
		}

		// Skip if it's a known internal device
		unsigned int i = sizeof(internal_devices)/sizeof(internal_devices[0]);
		bool found = false;
		while (i-- > 0 && !found) {
			if (internal_devices[i].vendor_id != vendor_id)
				continue;
			if (internal_devices[i].product_id != product_id)
				continue;
			// Found a match.
			found = true;
		}
		
		if (found) {
			IOObjectRelease(device);
			continue;
		}
		
		// Lookup vendor name
		NSString *vendor_name = [[self class] usbVendorById:vendor_id];

		NSMutableDictionary *dev_dict = [NSMutableDictionary dictionary];
		[dev_dict setValue:[NSNumber numberWithInt:vendor_id] forKey:@"vendor_id"];
		[dev_dict setValue:[NSNumber numberWithInt:product_id] forKey:@"product_id"];
		[dev_dict setValue:device_name forKey:@"device_name"];
		[dev_dict setValue:vendor_name forKey:@"vendor_name"];

		// Add to list if we can
		[lock lock];
		NSEnumerator *en = [devices objectEnumerator];
		NSDictionary *elt;
		bool isNew = true;
		while ((elt = [en nextObject]) && isNew) {
			if (([[elt objectForKey:@"vendor_id"] intValue] == vendor_id) &&
			    ([[elt objectForKey:@"product_id"] intValue] == product_id)) {
				// Already know about this device
				isNew = false;
			}
		}
		
		if (isNew) {
			//NSLog(@"USB >> [%d] Adding %@", cnt, dev_dict);
			[devices addObject:dev_dict];
			[self setDataCollected:YES];
            
		}
		
		[lock unlock];
        
        if (isNew)
            [[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
        
		IOObjectRelease(device);
	}
}

- (void)enumerateAll
{
	kern_return_t kr;
	io_iterator_t iterator = 0;

	// Create matching dictionary for I/O Kit enumeration
	CFMutableDictionaryRef matchDict = IOServiceMatching(kIOUSBDeviceClassName);
	kr = IOServiceGetMatchingServices(kIOMasterPortDefault, matchDict, &iterator);
	if (paranoid && (kr != KERN_SUCCESS))
		NSLog(@"USB enumerateAll >> IOServiceGetMatchingServices returned %d", kr);

	[lock lock];
	[devices removeAllObjects];
	[lock unlock];
	[self devAdded:iterator];
	[self setDataCollected:[devices count] > 0];

	IOObjectRelease(iterator);
}

+ (BOOL) isUSBAvailable {
	io_iterator_t ohci_iterator = 0;
    io_iterator_t ehci_iterator = 0;
    io_iterator_t xhci_iterator = 0;
    
    BOOL usbAvailable = FALSE;
    
	// Create matching dictionary for I/O Kit enumeration, one for
    // OHCI (USB 1), EHCI (USB 2) and XHCI (USB 3)
	CFMutableDictionaryRef ohci = IOServiceMatching("AppleUSBOHCI");
    CFMutableDictionaryRef ehci = IOServiceMatching("AppleUSBEHCI");
    CFMutableDictionaryRef xhci = IOServiceMatching("AppleUSBXHCI");
    
    
	IOServiceGetMatchingServices(kIOMasterPortDefault, ohci, &ohci_iterator);
  	IOServiceGetMatchingServices(kIOMasterPortDefault, ehci, &ehci_iterator);
  	IOServiceGetMatchingServices(kIOMasterPortDefault, xhci, &xhci_iterator);
    
    // assume that if we have a valid iterator then
    // we found a USB controller
    if (IOIteratorIsValid(ohci_iterator)) {
        usbAvailable = TRUE;
        IOObjectRelease(ohci_iterator);
    }
    
    if (IOIteratorIsValid(ehci_iterator)){
        usbAvailable = TRUE;
        IOObjectRelease(ehci_iterator);
    }
    
    if (IOIteratorIsValid(xhci_iterator)){
        usbAvailable = TRUE;
        IOObjectRelease(xhci_iterator);
    }
    
    return usbAvailable;
}

- (void)devRemoved:(io_iterator_t)iterator
{
	// When a USB device is removed, we usually don't get its details,
	// nor can we query those details (since it's removed, duh!). Thus
	// we do the simplest thing of doing a full rescan.
	io_service_t device;
	while ((device = IOIteratorNext(iterator)))
		IOObjectRelease(device);
	[self enumerateAll];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
}

#pragma mark Update stuff

- (void)doUpdate
{
	[self enumerateAll];		// be on the safe side
#ifdef DEBUG_MODE
	NSLog(@"%@ >> found %ld devices", [self class], (long) [devices count]);
#endif
}

- (void)clearCollectedData
{
	[lock lock];
	[devices removeAllObjects];
	[self setDataCollected:NO];
	[lock unlock];
}

- (void)start
{
	if (running)
		return;

	paranoid = [[NSUserDefaults standardUserDefaults] boolForKey:@"Debug USBParanoia"];
	if (paranoid)
		NSLog(@"USB Paranoia enabled.");

	notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
	runLoopSource = IONotificationPortGetRunLoopSource(notificationPort);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
	
	CFDictionaryRef matchDict = IOServiceMatching(kIOUSBDeviceClassName);
	CFRetain(matchDict);	// we use it twice
	
	IOServiceAddMatchingNotification(notificationPort, kIOMatchedNotification,
					 matchDict, devAdded, (void *) self,
					 &addedIterator);
	IOServiceAddMatchingNotification(notificationPort, kIOTerminatedNotification,
					 matchDict, devRemoved, (void *) self,
					 &removedIterator);

	// Prime notifications
	[self devAdded:addedIterator];
	[self devRemoved:removedIterator];

    running = YES;
	//[super start];
}

- (void)stop
{
	if (!running)
		return;

	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
	IONotificationPortDestroy(notificationPort);
	IOObjectRelease(addedIterator);
	IOObjectRelease(removedIterator);

    running = NO;
	//[super stop];
}

- (NSString *)name
{
	return @"USB";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	BOOL match = NO;

	NSArray *arr = [[rule objectForKey:@"parameter"] componentsSeparatedByString:@","];
	if ([arr count] != 2)
		return NO;	// a broken rule
	int vendor = [[arr objectAtIndex:0] intValue];
	int product = [[arr objectAtIndex:1] intValue];

	[lock lock];
	NSEnumerator *en = [devices objectEnumerator];
	NSDictionary *dev;
	while ((dev = [en nextObject])) {
		if (([[dev objectForKey:@"vendor_id"] intValue] == vendor) &&
		    ([[dev objectForKey:@"product_id"] intValue] == product)) {
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

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"The presence of", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions
{
	NSMutableArray *arr = [NSMutableArray array];

	[lock lock];
	NSEnumerator *en = [devices objectEnumerator];
	NSDictionary *dev;
	while ((dev = [en nextObject])) {
		NSString *param = [NSString stringWithFormat:@"%@,%@",
			[dev valueForKey:@"vendor_id"], [dev valueForKey:@"product_id"]];
		NSString *desc = [NSString stringWithFormat:@"%@ [%@]",
			[dev valueForKey:@"device_name"], [dev valueForKey:@"vendor_name"]];
		[arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			@"USB", @"type",
			param, @"parameter",
			desc, @"description", nil]];
	}
	[lock unlock];

	return arr;
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Attached USB Device", @"");
}

+ (BOOL) isEvidenceSourceApplicableToSystem {
    return [USBEvidenceSource isUSBAvailable];
}
@end
