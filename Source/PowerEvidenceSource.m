//
//  PowerEvidenceSource.m
//  ControlPlane
//
//  Created by Mark Wallis on 30/4/07.
//  Tweaks by David Symonds on 30/4/07.
//

#import <IOKit/IOKitLib.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>
#import "PowerEvidenceSource.h"


@interface PowerEvidenceSource (Private)

- (void)doFullUpdate;

@end


#pragma mark -

@implementation PowerEvidenceSource

- (id)init
{
	if (!(self = [super init]))
		return nil;

	status = nil;

	return self;
}

- (void)doFullUpdate
{
	CFTypeRef blob = IOPSCopyPowerSourcesInfo();
	NSArray *list = (NSArray *) IOPSCopyPowerSourcesList(blob);
	[list autorelease];

	BOOL onBattery = YES;
	NSEnumerator *en = [list objectEnumerator];
	CFTypeRef source;
	while ((source = [en nextObject])) {
		NSDictionary *dict = (NSDictionary *) IOPSGetPowerSourceDescription(blob, source);

		if ([[dict valueForKey:@kIOPSPowerSourceStateKey] isEqualToString:@kIOPSACPowerValue])
			onBattery = NO;
	}
	CFRelease(blob);

	if (onBattery)
		status = @"Battery";
	else
		status = @"A/C";
	[self setDataCollected:YES];
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

	status = nil;
	[self setDataCollected:NO];

	running = NO;
}

- (NSString *)name
{
	return @"Power";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	if (!status)
		return NO;
	return [[rule objectForKey:@"parameter"] isEqualToString:status];
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"Being powered by", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions
{
	return [NSArray arrayWithObjects:
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Power", @"type",
			@"Battery", @"parameter",
			NSLocalizedString(@"Battery", @""), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Power", @"type",
			@"A/C", @"parameter",
			NSLocalizedString(@"Power Adapter", @""), @"description", nil],
		nil];
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Power Source", @"");
}

@end
