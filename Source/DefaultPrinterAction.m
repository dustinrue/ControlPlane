//
//  DefaultPrinterAction.m
//  ControlPlane
//
//  Created by David Symonds on 3/04/07.
//

#import "DefaultPrinterAction.h"
#import <ScriptingBridge/SBApplication.h>
#import "Printer Setup Utility.h"
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

    PrinterSetupUtilityApplication *PSUA = [SBApplication applicationWithBundleIdentifier: @"com.apple.print.PrintCenter"];
    SBElementArray *availablePrinters = [PSUA printers];
  
    NSLog(@"%@",[self description]);
    
    // documentation says objectWithName returns nil if the object isn't found
    // I'm not seeing that at all so this will always succeed. 
    if ([availablePrinters objectWithName:printerQueue]) {
        [PSUA setCurrentPrinter:[availablePrinters objectWithName:printerQueue]];
    }
    else {
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
