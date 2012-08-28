//
//  AttachedPowerAdapterEvidenceSource.m
//  ControlPlane
//
//  Created by Dustin Rue on 8/27/12.
//
//

#import "AttachedPowerAdapterEvidenceSource.h"
#import "DSLogger.h"
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
    
	[super dealloc];
}


- (void)doFullUpdate {
    CFDictionaryRef powerAdapterInfo = IOPSCopyExternalPowerAdapterDetails();
    
    if (powerAdapterInfo)
        attachedPowerAdapter = [(NSDictionary *)powerAdapterInfo valueForKey:@"SerialNumber"];
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

- (void)start
{
	if (running)
		return;
    

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(doFullUpdate)
                                                 name:@"powerAdapterDidChangeNotification"
                                               object:nil];
    
	[self doFullUpdate];
    
	running = YES;
}

- (void)stop
{
	if (!running)
		return;
    
	// remove notifications
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self
                                                                  name:nil
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

    [currentAdapter release];

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

@end
