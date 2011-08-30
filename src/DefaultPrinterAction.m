//
//  DefaultPrinterAction.m
//  ControlPlane
//
//  Created by David Symonds on 3/04/07.
//

#import "DefaultPrinterAction.h"


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
	// got to escape forbidden characters
	NSString *printer = [[printerQueue stringByReplacingOccurrencesOfString:@" " withString:@"_"]
						 stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
	
	NSArray *args = [NSArray arrayWithObjects:@"-d", printer, nil];
	NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/lpoptions" arguments:args];
	[task waitUntilExit];

	if ([task terminationStatus] != 0) {
		*errorString = NSLocalizedString(@"Couldn't set default printer!", @"");
		return NO;
	}

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
	[self init];
	[printerQueue autorelease];
	printerQueue = [option copy];
	return self;
}

@end
