//
//  PowerEvidenceSource.m
//  MarcoPolo
//
//  Created by Mark Wallis <marcopolo@markwallis.id.au> on 30/4/07.
//  Tweaks by David Symonds on 30/4/07.
//

#import <IOKit/IOKitLib.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>
#import "PowerEvidenceSource.h"


@implementation PowerEvidenceSource

- (id)init
{
	if (!(self = [super init]))
		return nil;

	status = nil;
	[self setDataCollected:NO];

	return self;
}

- (void)dealloc
{
	[super blockOnThread];

	[super dealloc];
}

- (void)doUpdate
{
	if (!sourceEnabled) {
		status = nil;
		[self setDataCollected:NO];
		return;
	}

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

@end
