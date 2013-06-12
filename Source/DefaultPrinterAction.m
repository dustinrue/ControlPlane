//
//  DefaultPrinterAction.m
//  ControlPlane
//
//  Created by David Symonds on 3/04/07.
//

#import "DefaultPrinterAction.h"
#import <cups/cups.h>
#import "DSLogger.h"

@implementation DefaultPrinterAction

- (id)init
{
	if (!(self = [super init]))
		return nil;

	printerQueue = [[NSString alloc] init];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super initWithDictionary:dict]))
		return nil;

	printerQueue = [[dict valueForKey:@"parameter"] copy];

	return self;
}

- (void)dealloc
{
	[printerQueue release];

	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];

	[dict setObject:[[printerQueue copy] autorelease] forKey:@"parameter"];

	return dict;
}

- (NSString *)description
{
	return [NSString stringWithFormat:NSLocalizedString(@"Setting default printer to '%@'.", @""),
		printerQueue];
}

- (BOOL)execute:(NSString **)errorString
{
    int           j         = 0;
    int           num_dests = 0;
    cups_dest_t   *dests    = NULL;
    cups_dest_t   *dest     = NULL;
    const char    *printer  = NULL;
    char          *instance = NULL;
    
    NSCharacterSet *replaceThese = [NSCharacterSet characterSetWithCharactersInString:@" @-"];
    printer = [[[printerQueue componentsSeparatedByCharactersInSet: replaceThese] componentsJoinedByString: @"_"] cStringUsingEncoding:NSUTF8StringEncoding];
    
    
    DSLog(@"Attempting to set %s as default", printer);
    num_dests = cupsGetDests(&dests);
    
    if (num_dests == 0 || !dests || (dest = cupsGetDest(printer, instance, num_dests, dests)) == NULL) {
        *errorString = [NSString stringWithFormat:@"%@ %@",NSLocalizedString(@"Couldn't set default printer to", @""), printerQueue];
        return NO;
    }
    
    for (j = 0; j < num_dests; j++)
        dests[j].is_default = 0;

    dest->is_default = 1;
    
    cupsSetDests(num_dests, dests);
	
	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for DefaultPrinter actions is the name of the "
				 "printer queue. This is usually the name of the printer, with "
				 "spaces replaced by underscores.", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Change default printer to", @"");
}

+ (NSArray *)limitedOptions {
	NSArray *printers = [NSPrinter printerNames];
	NSMutableArray *opts = [NSMutableArray arrayWithCapacity:[printers count]];
	
	for (NSString *printer in printers)
		[opts addObject:[NSDictionary dictionaryWithObjectsAndKeys: printer, @"option", printer, @"description", nil]];
	
	return opts;
}

- (id)initWithOption:(NSString *)option
{
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
