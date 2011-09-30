//
//  DB.m
//  ControlPlane
//
//  Created by David Symonds on 29/03/07.
//

#import "DB.h"
#import "SynthesizeSingleton.h"

@interface DB (Private)

- (NSDictionary *) readOUIDB;
- (NSDictionary *) readUSBVendorDB;

@end

@implementation DB

SYNTHESIZE_SINGLETON_FOR_CLASS(DB);
@synthesize ouiDB = m_ouiDB;
@synthesize usbVendorDB = m_usbVendorDB;

- (id) init {
	ZAssert(!sharedDB, @"This is a singleton, use %@.shared%@", NSStringFromClass(self.class), NSStringFromClass(self.class));
	
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_ouiDB = [self readOUIDB];
	m_usbVendorDB = [self readUSBVendorDB];
	
	return self;
}

- (void) dealloc {
	[super dealloc];
}

- (NSDictionary *) readOUIDB {
	NSString *path = [[NSBundle mainBundle] pathForResource: @"oui" ofType: @"txt"];
	NSMutableDictionary *dict = [[NSMutableDictionary new] autorelease];
	
	// open file
	FILE *f = fopen([path cStringUsingEncoding: NSUTF8StringEncoding], "r");
	char buf[200];
	NSString *prefix, *vendor_name;
	
	// loop through lines
	while (!feof(f)) {
		if (!fgets(buf, sizeof(buf), f))
			break;
		
		// Line format:  00-00-4C   \t\tNEC CORPORATION
		NSString *line = [NSString stringWithCString: buf encoding: NSASCIIStringEncoding];
		if (!line)
			continue;
		
		// get data
		NSScanner *scan = [NSScanner scannerWithString: line];
		[scan scanUpToString: @"\t" intoString: &prefix];
		[scan scanUpToString: @"\n" intoString: &vendor_name];
		
		// store it
		[dict setValue: vendor_name forKey: prefix.uppercaseString];
	}
	fclose(f);
	
	return dict;
}

- (NSDictionary *) readUSBVendorDB {
	NSString *path = [[NSBundle mainBundle] pathForResource: @"usb-vendors" ofType: @"txt"];
	NSMutableDictionary *dict = [[NSMutableDictionary new] autorelease];
	
	// open file
	FILE *f = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "r");
	char buf[200];
	NSString *vendor_id, *vendor_name;
	
	// loop through lines
	while (!feof(f)) {
		if (!fgets(buf, sizeof(buf), f))
			break;
		
		// Line format:  1033|NEC Corporation
		NSString *line = [NSString stringWithCString: buf encoding: NSUTF8StringEncoding];
		if (!line)
			continue;
		
		// get data
		NSScanner *scan = [NSScanner scannerWithString: line];
		[scan scanUpToString: @"|" intoString: &vendor_id];
		[scan setScanLocation: [scan scanLocation] + 1];
		[scan scanUpToString: @"\n" intoString: &vendor_name];
		
		// store it
		[dict setValue: vendor_name forKey: vendor_id];
	}
	fclose(f);
	
	return dict;
}

@end
