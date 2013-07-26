//
//  AttachedPowerAdapterEvidenceSource.m
//  ControlPlane
//
//  Created by Dustin Rue on 8/27/12.
//
//

#import "AttachedPowerAdapterEvidenceSource.h"
#import "DSLogger.h"
#import "CPSystemInfo.h"
#import <IOKit/ps/IOPowerSources.h>

@implementation AttachedPowerAdapterEvidenceSource

@synthesize attachedPowerAdapter;

- (id)init
{
	if (!(self = [super init]))
		return nil;
    
    attachedPowerAdapter = nil;
    
	return self;
}

- (void)dealloc
{
    
	//[super dealloc];
}


- (NSString *) description {
    return NSLocalizedString(@"Create a rules based on what power adapter is currently connected to your portable mac based on its serial number", @"");
}

- (void)doFullUpdate {
    CFDictionaryRef powerAdapterInfo = IOPSCopyExternalPowerAdapterDetails();
    
    if (powerAdapterInfo)
        attachedPowerAdapter = [(__bridge NSDictionary *)powerAdapterInfo valueForKey:@"SerialNumber"];
    else
        attachedPowerAdapter = nil;
    
    if (attachedPowerAdapter) {
        [self setDataCollected:YES];
    }
    else {
        [self setDataCollected:NO];
    }
    
    if (powerAdapterInfo)
        CFRelease(powerAdapterInfo);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
}

- (void)start {
	if (running) {
		return;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(doFullUpdate)
                                                 name:@"powerAdapterDidChangeNotification"
                                               object:nil];

	[self doFullUpdate];

	running = YES;
}

- (void)stop {
	if (!running) {
		return;
    }

	// remove notifications
	[[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"powerAdapterDidChangeNotification"
                                                  object:nil];

	[lock lock];
	[self setDataCollected:NO];
	[lock unlock];
    
	running = NO;
}

- (NSString *)name
{
	return @"AttachedPowerAdapter";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
    NSString *param = [[rule valueForKey:@"parameter"] stringValue];
    BOOL match = NO;

    NSString *currentAdapter = [[attachedPowerAdapter stringValue] copy];

    if ([currentAdapter isEqualToString:param])
        match = YES;

   // [currentAdapter release];

    return match;
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"The following application is active", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions
{
    
    [self doFullUpdate];
	[lock lock];
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:1];
    
	
    
    [array addObject:
     [NSDictionary dictionaryWithObjectsAndKeys:
      @"AttachedPowerAdapter", @"type",
      attachedPowerAdapter, @"parameter",
      [NSString stringWithFormat:NSLocalizedString(@"Power adapter with serial: %@", @""), attachedPowerAdapter], @"description", nil]];

	[lock unlock];
    
    DSLog(@"stuff %@", array);
	return array;
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Attached Power Adapter", @"");
}

+ (BOOL) isEvidenceSourceApplicableToSystem {
    return [CPSystemInfo isPortable];
}

@end
