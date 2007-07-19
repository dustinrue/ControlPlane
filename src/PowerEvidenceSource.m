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


static void sourceChange(void *info)
{
#ifdef DEBUG_MODE
	NSLog(@"%s woo!", __PRETTY_FUNCTION__);
#endif
	PowerEvidenceSource *src = (PowerEvidenceSource *) info;

	[src doFullUpdate];
}

@implementation PowerEvidenceSource

- (id)init
{
	if (!(self = [super initWithNibNamed:@"PowerRule"]))
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

	// register for notifications
	runLoopSource = IOPSNotificationCreateRunLoopSource(sourceChange, self);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);

	[self doFullUpdate];

	running = YES;
}

- (void)stop
{
	if (!running)
		return;

	// remove notification registration
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
	CFRelease(runLoopSource);

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

- (NSMutableDictionary *)readFromPanel
{
	NSMutableDictionary *dict = [super readFromPanel];

	NSString *param = [[self valueForKey:@"batteryChosen"] boolValue] ? @"Battery" : @"A/C";
	[dict setValue:param forKey:@"parameter"];
	[dict setValue:param forKey:@"description"];

	return dict;
}

- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type
{
	[super writeToPanel:dict usingType:type];

	if ([dict objectForKey:@"parameter"]) {
		NSString *str = [dict valueForKey:@"parameter"];
		[self setValue:[NSNumber numberWithBool:[str isEqualToString:@"Battery"]]
			forKey:@"batteryChosen"];
	}
}

@end
