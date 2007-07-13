//
//  EvidenceSource.m
//  MarcoPolo
//
//  Created by David Symonds on 29/03/07.
//

#import "EvidenceSource.h"


@implementation EvidenceSource

- (id)init
{
	if ([[self class] isEqualTo:[EvidenceSource class]]) {
		[NSException raise:@"Abstract Class Exception"
			    format:@"Error, attempting to instantiate EvidenceSource directly."];
	}

	if (!(self = [super init]))
		return nil;

	running = NO;
	dataCollected = NO;	// or use KVO?
	startAfterSleep = NO;

	// Get notified when we go to sleep, and wake from sleep
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
							       selector:@selector(goingToSleep:)
								   name:@"NSWorkspaceWillSleepNotification"
								 object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
							       selector:@selector(wakeFromSleep:)
								   name:@"NSWorkspaceDidWakeNotification"
								 object:nil];

	return self;
}

- (void)dealloc
{
	[super dealloc];
}

//- (void)startThread
//{
//	if (![threadCond tryLockWhenCondition:ES_NOT_STARTED]) {
//		NSLog(@"WARNING: (%@) Thread already running!\n", [self class]);
//		return;
//	}
//
//	[NSThread detachNewThreadSelector:@selector(runThread:)
//				 toTarget:self
//			       withObject:nil];
//	[threadCond unlockWithCondition:ES_STARTING];
//
//	// Wait until started, then start an update timer, and get an update happening immediately
//	[threadCond lockWhenCondition:ES_IDLE];
//	updateTimer = [NSTimer scheduledTimerWithTimeInterval:updateInterval
//						       target:self
//						     selector:@selector(timerPoll:)
//						     userInfo:nil
//						      repeats:YES];
//	[threadCond unlockWithCondition:ES_UPDATING];
//}
//
//- (void)blockOnThread
//{
//	[threadCond lockWhenCondition:ES_IDLE];
//	timeToDie = YES;
//	[threadCond unlockWithCondition:ES_UPDATING];
//
//	// Wait until finished
//	[threadCond lockWhenCondition:ES_FINISHED];
//	[threadCond unlock];
//}

- (void)goingToSleep:(id)arg
{
#ifdef DEBUG_MODE
	NSLog(@"%@ >> About to go to sleep!", [self class]);
#endif
	if ([self isRunning]) {
		startAfterSleep = YES;
		[self stop];
	} else
		startAfterSleep = NO;
}

- (void)wakeFromSleep:(id)arg
{
#ifdef DEBUG_MODE
	NSLog(@"%@ >> Just woke from sleep!", [self class]);
#endif
	if (startAfterSleep)
		[self start];
}

- (BOOL)matchesRulesOfType:(NSString *)type
{
	return [[self typesOfRulesMatched] containsObject:type];
}

- (BOOL)dataCollected
{
	return dataCollected;
}

- (void)setDataCollected:(BOOL)collected
{
	dataCollected = collected;
}

- (BOOL)isRunning
{
	return running;
}

- (void)notImplemented:(NSString *)methodName
{
	[NSException raise:@"Abstract Class Exception"
		    format:[NSString stringWithFormat:@"Error, -%@ not implemented.", methodName]];
}

- (NSString *)name
{
	[self notImplemented:@"name"];
	return nil;
}

- (NSArray *)typesOfRulesMatched
{
	return [NSArray arrayWithObject:[self name]];
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	[self notImplemented:@"doesRuleMatch"];
	return NO;
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"The presence of", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions
{
	[self notImplemented:@"getSuggestions"];
	return nil;
}

- (void)start
{
	[self notImplemented:@"start"];
}

- (void)stop
{
	[self notImplemented:@"stop"];
}

@end

#pragma mark -

@implementation LoopingEvidenceSource

- (id)init
{
	if (!(self = [super init]))
		return nil;

	loopInterval = (NSTimeInterval) 10;	// 10 seconds, by default
	loopTimer = nil;

	return self;
}

- (void)dealloc
{
	if (loopTimer)
		[self stop];

	[super dealloc];
}

// Private
- (void)loopTimerPoll:(NSTimer *)timer
{
	if (timer) {
		[NSThread detachNewThreadSelector:@selector(loopTimerPoll:)
					 toTarget:self
				       withObject:nil];
		return;
	}

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

#ifdef DEBUG_MODE
	NSLog(@"%@ updating...", [self class]);
#endif
	[self performSelector:@selector(doUpdate)];

	[pool release];
}

- (void)start
{
	if (running)
		return;

	loopTimer = [NSTimer scheduledTimerWithTimeInterval:loopInterval
						     target:self
						   selector:@selector(loopTimerPoll:)
						   userInfo:nil
						    repeats:YES];
	[self loopTimerPoll:loopTimer];

	running = YES;
}

- (void)stop
{
	if (!running)
		return;

	[loopTimer invalidate];
	loopTimer = nil;

	[self performSelector:@selector(clearCollectedData)];
	[self setDataCollected:NO];

	running = NO;
}

@end

#pragma mark -

#import "AudioOutputEvidenceSource.h"
#import "BluetoothEvidenceSource.h"
#import "FireWireEvidenceSource.h"
#import "IPEvidenceSource.h"
#import "MonitorEvidenceSource.h"
#import "PowerEvidenceSource.h"
#import "RunningApplicationEvidenceSource.h"
#import "USBEvidenceSource.h"
#import "WiFiEvidenceSource.h"

@implementation EvidenceSourceSetController

- (id)init
{
	if (!(self = [super init]))
		return nil;

	NSArray *classes = [NSArray arrayWithObjects:
		[AudioOutputEvidenceSource class],
		[BluetoothEvidenceSource class],
		[FireWireEvidenceSource class],
		[IPEvidenceSource class],
		[MonitorEvidenceSource class],
		[PowerEvidenceSource class],
		[RunningApplicationEvidenceSource class],
		[USBEvidenceSource class],
		[WiFiEvidenceSource class],
		nil];
	if (NO) {
		// Purely for the benefit of 'genstrings'
		NSLocalizedString(@"AudioOutput", @"Evidence source");
		NSLocalizedString(@"Bluetooth", @"Evidence source");
		NSLocalizedString(@"FireWire", @"Evidence source");
		NSLocalizedString(@"IP", @"Evidence source");
		NSLocalizedString(@"Monitor", @"Evidence source");
		NSLocalizedString(@"Power", @"Evidence source");
		NSLocalizedString(@"RunningApplication", @"Evidence source");
		NSLocalizedString(@"USB", @"Evidence source");
		NSLocalizedString(@"WiFi", @"Evidence source");
	}

	// Instantiate all the evidence sources
	NSMutableArray *srclist = [[NSMutableArray alloc] initWithCapacity:[classes count]];
	NSEnumerator *en = [classes objectEnumerator];
	Class klass;
	while ((klass = [en nextObject])) {
		EvidenceSource *src = [[klass alloc] init];
		[srclist addObject:src];
	}
	sources = srclist;

	// Find all rule types supported
	NSMutableSet *types = [[NSMutableSet alloc] initWithCapacity:[sources count]];
	en = [sources objectEnumerator];
	EvidenceSource *src;
	while ((src = [en nextObject]))
		[types addObjectsFromArray:[src typesOfRulesMatched]];
	ruleTypes = [[types allObjects] sortedArrayUsingSelector:@selector(compare:)];

	return self;
}

- (void)dealloc
{
	[sources release];

	[super dealloc];
}

- (EvidenceSource *)sourceWithName:(NSString *)name
{
	NSEnumerator *en = [sources objectEnumerator];
	EvidenceSource *src;
	while ((src = [en nextObject]))
		if ([[src name] isEqualToString:name])
			return src;
	return nil;
}

- (void)startOrStopAll
{
	NSEnumerator *en = [sources objectEnumerator];
	EvidenceSource *src;
	while ((src = [en nextObject])) {
		NSString *key = [NSString stringWithFormat:@"Enable%@EvidenceSource", [src name]];
		BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:key];
		if (enabled && ![src isRunning])
			[src start];
		else if (!enabled && [src isRunning])
			[src stop];
	}
}

- (BOOL)ruleMatches:(NSDictionary *)rule
{
	NSEnumerator *en = [sources objectEnumerator];
	EvidenceSource *src;
	while ((src = [en nextObject])) {
		if (![src matchesRulesOfType:[rule objectForKey:@"type"]])
			continue;
		if ([src doesRuleMatch:rule])
			return YES;
	}
	return NO;
}

- (NSArray *)getSuggestionsFromSource:(NSString *)name ofType:(NSString *)type
{
	EvidenceSource *src = [self sourceWithName:name];

	if (!type)
		return [src getSuggestions];

	NSMutableArray *suggestions = [NSMutableArray array];
	NSArray *s_arr = [src getSuggestions];
	NSEnumerator *s_en = [s_arr objectEnumerator];
	NSDictionary *s_dict;
	while ((s_dict = [s_en nextObject])) {
		if ([[s_dict valueForKey:@"type"] isEqualToString:type])
			[suggestions addObject:s_dict];
	}

	return suggestions;
}

- (NSEnumerator *)sourceEnumerator
{
	return [sources objectEnumerator];
}

#pragma mark NSMenu delegates

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(int)index shouldCancel:(BOOL)shouldCancel
{
	EvidenceSource *src = [sources objectAtIndex:index];
	NSString *localisedName = NSLocalizedString([src name], @"Evidence source");

	NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Add %@ Rule...", @"Menu item"), localisedName];
	[item setTitle:title];

	if ([[src typesOfRulesMatched] count] > 1) {
		NSMenu *submenu = [[[NSMenu alloc] init] autorelease];
		NSEnumerator *en = [[src typesOfRulesMatched] objectEnumerator];
		NSString *type;
		while ((type = [en nextObject])) {
			NSMenuItem *it = [[[NSMenuItem alloc] init] autorelease];
			[it setTitle:NSLocalizedString(type, @"Rule type")];
			[it setTarget:prefsWindowController];
			[it setAction:@selector(addRule:)];
			[it setRepresentedObject:[NSArray arrayWithObjects:src, type, nil]];
			[submenu addItem:it];
		}
		[item setSubmenu:submenu];
	} else {
		[item setTarget:prefsWindowController];
		[item setAction:@selector(addRule:)];
		[item setRepresentedObject:src];
	}

	// Bindings
	[item bind:@"enabled" toObject:src withKeyPath:@"dataCollected" options:nil];
	// TODO?: enabled2 -> NSUserDefaults.values.Enable%@EvidenceSource

	return YES;
}

- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action
{
	// TODO: support keyboard menu jumping?
	return NO;
}

- (int)numberOfItemsInMenu:(NSMenu *)menu
{
	return [sources count];
}

#pragma mark NSTableViewDataSource protocol methods

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [sources count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	EvidenceSource *src = [sources objectAtIndex:rowIndex];
	NSString *col_id = [aTableColumn identifier];

	if ([col_id isEqualToString:@"enabled"]) {
		NSString *key = [NSString stringWithFormat:@"Enable%@EvidenceSource", [src name]];
		return [[NSUserDefaults standardUserDefaults] valueForKey:key];
	} else if ([col_id isEqualToString:@"name"]) {
		return NSLocalizedString([src name], @"Evidence source");
	}

	// Shouldn't get here!
	return nil;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	EvidenceSource *src = [sources objectAtIndex:rowIndex];
	NSString *col_id = [aTableColumn identifier];

	if ([col_id isEqualToString:@"enabled"]) {
		NSString *key = [NSString stringWithFormat:@"Enable%@EvidenceSource", [src name]];
		[[NSUserDefaults standardUserDefaults] setValue:anObject forKey:key];
		return;
	}

	// Shouldn't get here!
}

@end
