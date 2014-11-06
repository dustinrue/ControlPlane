//
//  DB.m
//  ControlPlane
//
//  Created by David Symonds on 29/03/07.
//  Code improvements by VladimirTechMan (Vladimir Beloborodov) on 06 Nov 2014.
//

#import "DB.h"
#import "DSLogger.h"

static NSDictionary *ouiDb = nil;
static NSDictionary *usbVendorDb = nil;


@implementation DB

+ (NSDictionary *)sharedOUIDB
{
	if (ouiDb == nil) {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        
		NSString *path = [[NSBundle mainBundle] pathForResource:@"oui" ofType:@"txt"];
		FILE *f = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "r");
        
		// TODO: handle failure
		while (!feof(f)) {
			char buf[200];
            if (!fgets(buf, sizeof(buf), f)) {
                break;
            }
			// Line format:  00-00-4C   \t\tNEC CORPORATION
			NSString *line = [NSString stringWithCString:buf encoding:NSASCIIStringEncoding];
            if (line == nil) {
                continue;	// bad line
            }
			NSScanner *scan = [NSScanner scannerWithString:line];
			NSString *prefix = nil, *vendorName = nil;
            BOOL successfulScan = (   [scan scanUpToString:@"\t" intoString:&prefix]
                                   // (NSScanner will skip over the white space)
                                   && [scan scanUpToString:@"\n" intoString:&vendorName] );
            if (successfulScan) {
                prefix = [prefix uppercaseString];
                [dict setValue:vendorName forKey:prefix];
            } else {
                DSLog(@"Failed to parse file \"oui.txt\": unexpected format of line \"%@\"", line);
                break;
            }
		}
		fclose(f);
        
		ouiDb = dict;
	}

	return ouiDb;
}

+ (NSDictionary *)sharedUSBVendorDB
{
	if (usbVendorDb == nil) {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        
		NSString *path = [[NSBundle mainBundle] pathForResource:@"usb-vendors" ofType:@"txt"];
		FILE *f = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "r");
		// TODO: handle failure
		while (!feof(f)) {
			char buf[200];
            if (!fgets(buf, sizeof(buf), f)) {
                break;
            }
			// Line format:  1033|NEC Corporation
            NSString *delimiter = @"|";
			NSString *line = [NSString stringWithCString:buf encoding:NSUTF8StringEncoding];
			NSScanner *scan = [NSScanner scannerWithString:line];
			NSString *vendorID = nil, *vendorName = nil;
            BOOL successfulScan = (   [scan scanUpToString:delimiter intoString:&vendorID]
                                   && [scan scanString:delimiter intoString:NULL]
                                   && [scan scanUpToString:@"\n" intoString:&vendorName] );
            if (successfulScan) {
                [dict setValue:vendorName forKey:vendorID];
            } else {
                DSLog(@"Failed to parse file \"usb-vendors.txt\": unexpected format of line \"%@\"", line);
                break;
            }
		}
		fclose(f);
        
		usbVendorDb = dict;
	}
    
	return usbVendorDb;
}

@end
