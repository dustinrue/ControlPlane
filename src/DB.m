//
//  DB.m
//  MarcoPolo
//
//  Created by David Symonds on 29/03/07.
//

#import "DB.h"


static NSDictionary *ouiDb = nil;
static NSDictionary *usbVendorDb = nil;


@implementation DB

+ (NSDictionary *)sharedOUIDB
{
	if (!ouiDb) {
		NSString *path = [[NSBundle mainBundle] pathForResource:@"oui" ofType:@"txt"];
		NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
		FILE *f = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "r");
		// TODO: handle failure
		while (!feof(f)) {
			char buf[200];
			if (!fgets(buf, sizeof(buf), f))
				break;
			// Line format:  00-00-4C   \t\tNEC CORPORATION
			NSString *line = [NSString stringWithCString:buf encoding:NSASCIIStringEncoding];
			if (!line)
				continue;	// bad line
			NSScanner *scan = [NSScanner scannerWithString:line];
			NSString *prefix, *vendor_name;
			[scan scanUpToString:@" " intoString:&prefix];
			prefix = [prefix lowercaseString];
			// (NSScanner will skip over the white space)
			[scan scanUpToString:@"\n" intoString:&vendor_name];

			[dict setValue:vendor_name forKey:prefix];
		}
		fclose(f);
		ouiDb = dict;
	}

	return ouiDb;
}

+ (NSDictionary *)sharedUSBVendorDB
{
	if (!usbVendorDb) {
		NSString *path = [[NSBundle mainBundle] pathForResource:@"usb-vendors" ofType:@"txt"];
		NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
		FILE *f = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "r");
		// TODO: handle failure
		while (!feof(f)) {
			char buf[200];
			if (!fgets(buf, sizeof(buf), f))
				break;
			// Line format:  1033|NEC Corporation
			NSString *line = [NSString stringWithCString:buf encoding:NSUTF8StringEncoding];
			NSScanner *scan = [NSScanner scannerWithString:line];
			NSString *vendor_id, *vendor_name;
			[scan scanUpToString:@"|" intoString:&vendor_id];
			[scan setScanLocation:[scan scanLocation] + 1];
			[scan scanUpToString:@"\n" intoString:&vendor_name];

			[dict setValue:vendor_name forKey:vendor_id];
		}
		fclose(f);
		usbVendorDb = dict;
	}

	return usbVendorDb;
}

@end
