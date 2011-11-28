//
//  EvidenceSource.m
//  ControlPlane
//
//  Created by David Symonds on 29/03/07.
//  Modified by Dustin Rue on 8/5/2011.
//

#import "DSLogger.h"
#import "EvidenceSource.h"
#import "PrefsWindowController.h"


@interface EvidenceSource (Private)

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end

#pragma mark -

@implementation EvidenceSource

- (id)initWithNibNamed:(NSString *)name
{
	if ([[self class] isEqualTo:[EvidenceSource class]]) {
		[NSException raise:@"Abstract Class Exception"
			    format:@"Error, attempting to instantiate EvidenceSource directly."];
	}

	if (!(self = [super init]))
		return nil;

	running = NO;
	dataCollected = NO;
	startAfterSleep = NO;
    goingToSleep = NO;

	oldDescription = nil;

	// load nib
	NSNib *nib = [[[NSNib alloc] initWithNibNamed:name bundle:nil] autorelease];
	if (!nib) {
		NSLog(@"%@ >> failed loading nib named '%@'!", [self class], name);
		return nil;
	}
	NSArray *topLevelObjects = [NSArray array];
	if (![nib instantiateNibWithOwner:self topLevelObjects:&topLevelObjects]) {
		NSLog(@"%@ >> failed instantiating nib (named '%@')!", [self class], name);
		return nil;
	}

	// Look for an NSPanel
	panel = nil;
	NSEnumerator *en = [topLevelObjects objectEnumerator];
	NSObject *obj;
	while ((obj = [en nextObject])) {
		if ([obj isKindOfClass:[NSPanel class]] && !panel)
			panel = (NSPanel *) [obj retain];
	}
	if (!panel) {
		NSLog(@"%@ >> failed to find an NSPanel in nib named '%@'!", [self class], name);
		return nil;
	}

	// Get notified when we go to sleep, and wake from sleep
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
							       selector:@selector(goingToSleep:)
								   name:@"NSWorkspaceWillSleepNotification"
								 object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
							       selector:@selector(wakeFromSleep:)
								   name:@"NSWorkspaceDidWakeNotification"
								 object:nil];

    rulesThatBelongToThisEvidenceSource = [[NSMutableArray alloc] init];
    
	return self;
}

- (void)dealloc
{
	[panel release];

	if (oldDescription)
		[oldDescription release];

	[super dealloc];
}

- (void)goingToSleep:(id)arg
{
    goingToSleep = YES;
	if ([self isRunning]) {
		DSLog(@"Stopping %@ for sleep.", [self class]);
		startAfterSleep = YES;
		[self stop];
	} else
		startAfterSleep = NO;
}

- (void)wakeFromSleep:(id)arg
{
    goingToSleep = NO;
	if (startAfterSleep) {
		DSLog(@"Starting %@ after sleep.", [self class]);
		[self start];
	}
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

- (void)setThreadNameFromClassName
{
	// Mac OS X 10.5 (Leopard) introduces -[NSThread setName:], which might make crash logs easier to read
	NSThread *thr = [NSThread currentThread];
	if ([thr respondsToSelector:@selector(setName:)])
		[thr performSelector:@selector(setName:) withObject:NSStringFromClass([self class])];
}

#pragma mark -
#pragma mark Sheet hooks

- (void)setContextMenu:(NSMenu *)menu
{
	[ruleContext setMenu:menu];
}

- (void)runPanelAsSheetOfWindow:(NSWindow *)window withParameter:(NSDictionary *)parameter
		 callbackObject:(NSObject *)callbackObject selector:(SEL)selector
{
	NSString *typeToUse = [[self typesOfRulesMatched] objectAtIndex:0];
	if ([parameter objectForKey:@"type"])
		typeToUse = [parameter valueForKey:@"type"];
	[self writeToPanel:parameter usingType:typeToUse];

	NSMethodSignature *sig = [callbackObject methodSignatureForSelector:selector];
	NSInvocation *contextInfo = [NSInvocation invocationWithMethodSignature:sig];
	[contextInfo setSelector:selector];
	[contextInfo setTarget:callbackObject];

	[NSApp beginSheet:panel
	   modalForWindow:window
	    modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
	      contextInfo:[contextInfo retain]];
}

- (IBAction)closeSheetWithOK:(id)sender
{
	[NSApp endSheet:panel returnCode:NSOKButton];
	[panel orderOut:nil];
}

- (IBAction)closeSheetWithCancel:(id)sender
{
	[NSApp endSheet:panel returnCode:NSCancelButton];
	[panel orderOut:nil];
}

// Private
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode != NSOKButton)
		return;

	NSInvocation *inv = (NSInvocation *) contextInfo;
	NSDictionary *dict = [self readFromPanel];
	[inv setArgument:&dict atIndex:2];

	[inv invoke];
	[inv release];
}

- (NSMutableDictionary *)readFromPanel
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[[ruleContext selectedItem] representedObject], @"context",
		[NSNumber numberWithDouble:[ruleConfidenceSlider doubleValue]], @"confidence",
		[[self typesOfRulesMatched] objectAtIndex:0], @"type",
		nil];

	if (oldDescription)
		[dict setValue:oldDescription forKey:@"description"];

	return dict;
}

- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type
{
	if ([dict objectForKey:@"context"]) {
		// Set up context selector
		NSInteger index = [ruleContext indexOfItemWithRepresentedObject:[dict valueForKey:@"context"]];
		[ruleContext selectItemAtIndex:index];
	}

	if ([dict objectForKey:@"confidence"]) {
		// Set up confidence slider
		[ruleConfidenceSlider setDoubleValue:[[dict valueForKey:@"confidence"] doubleValue]];
	}

	// Hang on to custom descriptions
	[oldDescription autorelease];
	oldDescription = nil;
	if ([dict objectForKey:@"description"]) {
		NSString *desc = [dict valueForKey:@"description"];
		if (desc && ([desc length] > 0))
			oldDescription = [desc retain];
	}
}


#pragma mark -


- (NSArray *)myRules {
    
    NSMutableArray *tmp = [[[NSMutableArray alloc] init] autorelease];
    [tmp addObjectsFromArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"Rules"]];
    
    NSDictionary *currentRule;

    for (NSUInteger i = 0; i < [tmp count]; i++) {
        currentRule = [tmp objectAtIndex:i];
        NSString *currentType = [[[NSString alloc] initWithString:[currentRule valueForKey:@"type"]] autorelease];
        DSLog(@"comparing %@ to %@", currentType, [[self typesOfRulesMatched] objectAtIndex:0]);
        
        if ([currentType isEqualToString:[[self typesOfRulesMatched] objectAtIndex:0]]) {
            [rulesThatBelongToThisEvidenceSource addObject:currentRule];
        }

    }

    return rulesThatBelongToThisEvidenceSource;
}

- (void)start
{
	[self doesNotRecognizeSelector:_cmd];
}

- (void)stop
{
	[self doesNotRecognizeSelector:_cmd];
}

- (NSString *)name
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (NSArray *)typesOfRulesMatched
{
	return [NSArray arrayWithObject:[self name]];
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	[self doesNotRecognizeSelector:_cmd];
	return NO;
}

@end

#pragma mark -

@interface EvidenceSourceSetController (Private)

// NSMenu delegates (for adding rules)
- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(int)index shouldCancel:(BOOL)shouldCancel;
- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action;
- (NSUInteger)numberOfItemsInMenu:(NSMenu *)menu;

// NSTableViewDataSource protocol methods
- (NSUInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;

@end

#import "AudioOutputEvidenceSource.h"
#import "BluetoothEvidenceSource.h"
#import "BonjourEvidenceSource.h"
#import "FireWireEvidenceSource.h"
#import "IPEvidenceSource.h"
#import "LightEvidenceSource.h"
#import "MonitorEvidenceSource.h"
#import "NetworkLinkEvidenceSource.h"
#import "PowerEvidenceSource.h"
#import "RunningApplicationEvidenceSource.h"
#import "TimeOfDayEvidenceSource.h"
#import "USBEvidenceSource.h"
#import "CoreWLANEvidenceSource.h"
#import "ShellScriptEvidenceSource.h"
#import "SleepEvidenceSource.h"
#import "CoreLocationSource.h"

@implementation EvidenceSourceSetController

- (id)init
{
	if (!(self = [super init]))
		return nil;
    
	NSArray *classes = [NSArray arrayWithObjects:
						[AudioOutputEvidenceSource class],
						[BluetoothEvidenceSource class],
						[BonjourEvidenceSource class],
						[CoreLocationSource class],
						[FireWireEvidenceSource class],
						[IPEvidenceSource class],
						[LightEvidenceSource class],
						[MonitorEvidenceSource class],
						[NetworkLinkEvidenceSource class],
						[PowerEvidenceSource class],
						[RunningApplicationEvidenceSource class],
						[SleepEvidenceSource class],
						[TimeOfDayEvidenceSource class],
						[USBEvidenceSource class],
						[WiFiEvidenceSourceCoreWLAN class],
                        [ShellScriptEvidenceSource class],
						nil];
	if (NO) {
		// Purely for the benefit of 'genstrings'
		NSLocalizedString(@"AudioOutput", @"Evidence source");
		NSLocalizedString(@"Bluetooth", @"Evidence source");
		NSLocalizedString(@"Bonjour", @"Evidence source");
		NSLocalizedString(@"CoreLocation", @"Evidence source");
		NSLocalizedString(@"FireWire", @"Evidence source");
		NSLocalizedString(@"IP", @"Evidence source");
		NSLocalizedString(@"Light", @"Evidence source");
		NSLocalizedString(@"Monitor", @"Evidence source");
		NSLocalizedString(@"NetworkLink", @"Evidence source");
		NSLocalizedString(@"Power", @"Evidence source");
		NSLocalizedString(@"RunningApplication", @"Evidence source");
		NSLocalizedString(@"Sleep/Wake", @"Evidence source");
		NSLocalizedString(@"TimeOfDay", @"Evidence source");
		NSLocalizedString(@"USB", @"Evidence source");
        NSLocalizedString(@"WiFi using CoreWLAN", @"Evidence source");
        NSLocalizedString(@"Shell Script", @"Evidence source");
	}

	// Instantiate all the evidence sources
	NSMutableArray *srclist = [[NSMutableArray alloc] initWithCapacity:[classes count]];
	NSEnumerator *en = [classes objectEnumerator];
	Class klass;
	while ((klass = [en nextObject])) {
		EvidenceSource *src = [[klass alloc] init];
		[srclist addObject:src];
		[src release];
	}
	sources = srclist;

	// Find all rule types supported
	NSMutableSet *types = [[NSMutableSet alloc] initWithCapacity:[sources count]];
	en = [sources objectEnumerator];
	EvidenceSource *src;
	while ((src = [en nextObject]))
		[types addObjectsFromArray:[src typesOfRulesMatched]];
	ruleTypes = [[types allObjects] sortedArrayUsingSelector:@selector(compare:)];
	[types release];

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
    // walk through all of the Evidence Sources that are enabled
    // and issue a start on each one
	NSEnumerator *en = [sources objectEnumerator];
	EvidenceSource *src;
	while ((src = [en nextObject])) {
		NSString *key = [NSString stringWithFormat:@"Enable%@EvidenceSource", [src name]];
		BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:key];
#ifdef DEBUG_MODE
        DSLog(@"checking to see if %@ is enabled",[src name]);
#endif
		if (enabled && ![src isRunning]) {
#ifdef DEBUG_MODE
            DSLog(@"Starting %@ evidence source because it is enabled", [src name]);
#endif
			DSLog(@"Starting %@ evidence source", [src name]);
			[src start];
		} else if (!enabled && [src isRunning]) {
#ifdef DEBUG_MODE
      		DSLog(@"Stopping %@ evidence source because it is disabled", [src name]);
#endif
			DSLog(@"Stopping %@ evidence source", [src name]);
			[src stop];
		}
	}
}

- (BOOL)ruleMatches:(NSDictionary *)rule
{
	NSEnumerator *en = [sources objectEnumerator];
	EvidenceSource *src;
	while ((src = [en nextObject])) {
        NSString *key = [NSString stringWithFormat:@"Enable%@EvidenceSource", [src name]];
		BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:key];

		if (![src matchesRulesOfType:[rule objectForKey:@"type"]])
			continue;
		if (enabled && [src isRunning] && [src doesRuleMatch:rule]) {
#if DEBUG_MODE
            DSLog(@"checking EvidenceSource %@ for matching rules", src);
#endif
            return YES;
        }
			
	}
	return NO;
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

- (NSUInteger)numberOfItemsInMenu:(NSMenu *)menu
{
	return [sources count];
}

#pragma mark NSTableViewDataSource protocol methods

- (NSUInteger)numberOfRowsInTableView:(NSTableView *)aTableView
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
