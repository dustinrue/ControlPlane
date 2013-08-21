//
//  DefaultPrinterAction.m
//  ControlPlane
//
//  Created by David Symonds on 3/04/07.
//  Minor improvements done by Vladimir Beloborodov (VladimirTechMan) on 20 Aug 2013.
//

#import <cups/cups.h>
#import "DefaultPrinterAction.h"
#import "DSLogger.h"

@implementation DefaultPrinterAction

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

- (BOOL)execute:(NSString **)errorString {
    NSCharacterSet *replaceThese = [NSCharacterSet characterSetWithCharactersInString:@" @-"];
    const char *printer = [[[printerQueue componentsSeparatedByCharactersInSet:replaceThese]
                                    componentsJoinedByString:@"_"] cStringUsingEncoding:NSUTF8StringEncoding];

    DSLog(@"Attempting to set '%s' as default", printer);

    cups_dest_t *dests = NULL;
    int num_dests = cupsGetDests(&dests);
    if (num_dests == 0 || !dests) {
        DSLog(@"Failed to get the list of printers from the system");
        NSString *fmt = NSLocalizedString(@"Couldn't set default printer to %@"
                                          " (see the log for more details)", @"");
        *errorString = [NSString stringWithFormat:fmt, printerQueue];
        return NO;
    }

    char *instance = NULL;
    cups_dest_t *dest = cupsGetDest(printer, instance, num_dests, dests);
    if (!dest) {
        DSLog(@"Cannot find '%s' in the list of printers known to the system", printer);
        NSString *fmt = NSLocalizedString(@"Couldn't set default printer to %@"
                                          " (see the log for more details)", @"");
        *errorString = [NSString stringWithFormat:fmt, printerQueue];
        return NO;
    }

    if (!dest->is_default) {
        for (int j = 0; j < num_dests; j++) {
            dests[j].is_default = 0;
        }
        dest->is_default = 1;
        
        cupsSetDests(num_dests, dests);
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
		[opts addObject:@{ @"option": printer, @"description":printer }];
    }
	
	return opts;
}

- (id)initWithOption:(NSString *)option {
	self = [super init];
	[printerQueue autorelease];
	printerQueue = [option copy];
	return self;
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Default Printer", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"System Preferences", @"");
}

@end
