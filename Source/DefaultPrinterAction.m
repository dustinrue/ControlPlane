//
//  DefaultPrinterAction.m
//  ControlPlane
//
//  Created by David Symonds on 3/04/07.
//  Reworked by Vladimir Beloborodov (VladimirTechMan) on 20-21 Aug 2013.
//

#import "DefaultPrinterAction.h"
#import "DSLogger.h"

@implementation DefaultPrinterAction {
	NSString *printerQueue;
}

- (id)init {
	if (!(self = [super init])) {
		return nil;
    }

	printerQueue = [[NSString alloc] init];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict {
	if (!(self = [super initWithDictionary:dict])) {
		return nil;
    }

	printerQueue = [dict[@"parameter"] copy];

	return self;
}

- (void)dealloc {
	[printerQueue release];

	[super dealloc];
}

- (NSMutableDictionary *)dictionary {
	NSMutableDictionary *dict = [super dictionary];

	dict[@"parameter"] = [[printerQueue copy] autorelease];

	return dict;
}

- (NSString *)description {
	return [NSString stringWithFormat:NSLocalizedString(@"Setting default printer to '%@'.", @""), printerQueue];
}

+ (BOOL)setDefaultPrinterByPrinterName:(NSString *)name {
    CFArrayRef printers = NULL;
    OSStatus result = PMServerCreatePrinterList(kPMServerLocal, &printers);
    if (result != noErr) {
        DSLog(@"Failed to get printer list (result code is %d)", result);
        return NO;
    }

    PMPrinter matchingPrinter = NULL;
    for (CFIndex i = 0, count = CFArrayGetCount(printers); i < count; ++i) {
        PMPrinter printer = (PMPrinter) CFArrayGetValueAtIndex(printers, i);
        CFStringRef printerName = PMPrinterGetName((PMPrinter) printer);
        if ([name isEqualToString:(NSString *) printerName]) {
            matchingPrinter = printer;
            break;
        }
    }

    if (!matchingPrinter) {
        DSLog(@"Cannot find printer with name '%@' in your system", name);
        CFRelease(printers);
        return NO;
    }

    result = PMPrinterSetDefault(matchingPrinter);
    if (result != noErr) {
        DSLog(@"Error reported on attempt to set printer '%@' as default (result code is %d)", name, result);
        CFRelease(printers);
        return NO;
    }

    CFRelease(printers);
    return YES;
}

- (BOOL)execute:(NSString **)errorString {
    DSLog(@"Attempting to set '%@' as default", printerQueue);

    if (![[self class] setDefaultPrinterByPrinterName:printerQueue]) {
        NSString *fmt = NSLocalizedString(@"Couldn't set default printer to %@"
                                          " (see the log for more details)", @"");
        *errorString = [NSString stringWithFormat:fmt, printerQueue];
        return NO;
    }

	return YES;
}

+ (NSString *)helpText {
	return NSLocalizedString(@"The parameter for DefaultPrinter actions is the name of the"
                             " printer queue. This is usually the name of the printer, with"
                             " spaces replaced by underscores.", @"");
}

+ (NSString *)creationHelpText {
	return NSLocalizedString(@"Change default printer to", @"");
}

+ (NSArray *)limitedOptions {
	NSArray *printers = [NSPrinter printerNames];
	NSMutableArray *opts = [NSMutableArray arrayWithCapacity:[printers count]];
	
	for (NSString *printer in printers) {
		[opts addObject:@{ @"option":printer, @"description":printer }];
    }
	
	return opts;
}

- (id)initWithOption:(NSString *)option {
	self = [super init];
	[printerQueue autorelease];
	printerQueue = [option copy];
	return self;
}

+ (NSString *)friendlyName {
    return NSLocalizedString(@"Default Printer", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"System Preferences", @"");
}

@end
