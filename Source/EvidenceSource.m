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

@synthesize screenIsLocked;

- (id)initWithPanel:(NSPanel *)initPanel {
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
    screenIsLocked = NO;
    
	oldDescription = nil;

    panel = initPanel;

	// Get notified when we go to sleep, and wake from sleep
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(goingToSleep:)
                                                 name:@"systemWillSleep"
                                               object:nil];
    
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(wakeFromSleep:)
                                                 name:@"systemDidWake"
                                               object:nil];
    
    // Monitor screensaver status
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(screenSaverDidBecomeInActive:)
                                                            name:@"com.apple.screensaver.didstop"
                                                          object:nil];
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(screenSaverDidBecomeActive:)
                                                            name:@"com.apple.screensaver.didstart"
                                                          object:nil];
    
    
    
    // Monitor screen lock status
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(screenDidUnlock:)
                                                            name:@"com.apple.screenIsUnlocked"
                                                          object:nil];
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(screenDidLock:)
                                                            name:@"com.apple.screenIsLocked"
                                                          object:nil];
    
	return self;
}

+ (NSPanel *)getPanelFromNibNamed:(NSString *)name instantiatedWithOwner:(id)owner {
	// load nib
	NSNib *nib = [[[NSNib alloc] initWithNibNamed:name bundle:nil] autorelease];
	if (!nib) {
		NSLog(@"%@ >> failed loading nib named '%@'!", [self class], name);
		return nil;
	}

	NSArray *topLevelObjects = nil;
    if ([nib respondsToSelector:@selector(instantiateWithOwner:topLevelObjects:)]) {
        if (![nib instantiateWithOwner:owner topLevelObjects:&topLevelObjects]) {
            NSLog(@"%@ >> failed instantiating nib (named '%@')!", [self class], name);
            return nil;
        }
    } else {
        if (![nib instantiateNibWithOwner:owner topLevelObjects:&topLevelObjects]) {
            NSLog(@"%@ >> failed instantiating nib (named '%@')!", [self class], name);
            return nil;
        }
    }
    
	// Look for an NSPanel
    for (NSObject *obj in topLevelObjects) {
        if ([obj isKindOfClass:[NSPanel class]]) {
            return (NSPanel *) obj;
        }
    }

    NSLog(@"%@ >> failed to find an NSPanel in nib named '%@'!", [self class], name);
    return nil;
}

- (id)initWithNibNamed:(NSString *)name {
    if (!(self = [self initWithPanel:nil])) {
        return nil;
    }
    
    panel = [[[self class] getPanelFromNibNamed:name instantiatedWithOwner:self] retain];
    if (!panel) {
        [self release];
        return nil;
    }

    return self;
}

- (void)dealloc {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

	[panel release];

	if (oldDescription) {
		[oldDescription release];
    }

	[super dealloc];
}


- (NSString *)description {
    return NSLocalizedString(@"No description provided", @"");
}

- (void)goingToSleep:(id)arg {
    goingToSleep = YES;
	if ([self isRunning]) {
		DSLog(@"Stopping %@ for sleep.", [self class]);
		startAfterSleep = YES;
		[self stop];
	} 
}

- (void)wakeFromSleep:(id)arg {
    goingToSleep = NO;
	if (startAfterSleep) {
		DSLog(@"Starting %@ after sleep.", [self class]);
		[self start];
        startAfterSleep = NO;
	}
}

- (BOOL)matchesRulesOfType:(NSString *)type {
	return [[self typesOfRulesMatched] containsObject:type];
}

- (BOOL)dataCollected {
	return dataCollected;
}

- (void)setDataCollected:(BOOL)collected {
	dataCollected = collected;
}

- (BOOL)isRunning {
	return running;
}

- (void)setThreadNameFromClassName {
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
    NSInvocation *inv = (NSInvocation *) contextInfo;

	if (returnCode == NSOKButton) {
        NSDictionary *dict = [self readFromPanel];
        [inv setArgument:&dict atIndex:2];
        [inv invoke];
    }

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
    if (!rulesThatBelongToThisEvidenceSource) {
        rulesThatBelongToThisEvidenceSource = [[NSMutableArray alloc] init];
    }
    
    // clear out existing rules if they exist
    if ([rulesThatBelongToThisEvidenceSource count] > 0)
        [rulesThatBelongToThisEvidenceSource removeAllObjects];

    NSMutableArray *tmp = [[[NSMutableArray alloc] init] autorelease];
    [tmp addObjectsFromArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"Rules"]];
    
    NSDictionary *currentRule;

    for (NSUInteger i = 0; i < [tmp count]; i++) {
        currentRule = [tmp objectAtIndex:i];
        NSString *currentType = [[[NSString alloc] initWithString:[currentRule valueForKey:@"type"]] autorelease];
        
        if ([currentType isEqualToString:[[self typesOfRulesMatched] objectAtIndex:0]]) {
            [rulesThatBelongToThisEvidenceSource addObject:currentRule];
        }

    }

    return rulesThatBelongToThisEvidenceSource;
}

- (void)start {
	[self doesNotRecognizeSelector:_cmd];
}

- (void)stop {
	[self doesNotRecognizeSelector:_cmd];
}

- (NSString *)name {
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (NSArray *)typesOfRulesMatched {
	return [NSArray arrayWithObject:[self name]];
}

- (BOOL)doesRuleMatch:(NSMutableDictionary *)rule {
	[self doesNotRecognizeSelector:_cmd];
	return NO;
}

- (NSString *) friendlyName {
    return @"Not implemented";
}

- (NSString *)enablementKeyName {
    NSMutableString *key = [NSMutableString stringWithString:@"Enable"];
    [key appendString:[self name]];
    [key appendString:@"EvidenceSource"];
    return [NSString stringWithString:key];
}

// if the evidence source doesn't override this we assume
// it is always true, thus the evidence source will be available
+ (BOOL) isEvidenceSourceApplicableToSystem {
    return true;
}

- (void) screenSaverDidBecomeInActive:(NSNotification *)notification {
    
}

- (void) screenSaverDidBecomeActive:(NSNotification *)notification {
    
}

- (void) screenDidUnlock:(NSNotification *)notification {
    [self setScreenIsLocked:NO];
}

- (void) screenDidLock:(NSNotification *)notification {
    [self setScreenIsLocked:YES];
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
- (NSArray *)getEvidenceSourcePlugins;

@end

#import "ActiveApplicationEvidenceSource.h"
#import "AttachedPowerAdapterEvidenceSource.h"
#import "AudioOutputEvidenceSource.h"
#import "BluetoothEvidenceSource.h"
#import "BonjourEvidenceSource.h"
#import "DNSEvidenceSource.h"
#import "FireWireEvidenceSource.h"
#import "IPAddrEvidenceSource.h"
#import "LaptopLidEvidenceSource.h"
#import "LightEvidenceSource.h"
#import "LaptopLidEvidenceSource.h"
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
#import "HostAvailabilityEvidenceSource.h"

#import "CPSystemInfo.h"

#ifdef DEBUG_MODE
#import "StressTestEvidenceSource.h"
#endif

@implementation EvidenceSourceSetController {
    NSMutableDictionary *enabledSourcesForRuleTypes;
}

- (id)init {
	if (!(self = [super init])) {
		return nil;
    }

	NSMutableArray *classes = [NSMutableArray arrayWithObjects:
#ifdef DEBUG_MODE
                        [StressTestEvidenceSource class],
#endif
                        [ActiveApplicationEvidenceSource class],
                        [AttachedPowerAdapterEvidenceSource class],
                        [NetworkLinkEvidenceSource class],
                        [IPAddrEvidenceSource class],
                        [FireWireEvidenceSource class],
                        [MonitorEvidenceSource class],
                        [USBEvidenceSource class],
						[AudioOutputEvidenceSource class],
                        //[HostAvailabilityEvidenceSource class],
						[BluetoothEvidenceSource class],
                        [BonjourEvidenceSource class],	
						[CoreLocationSource class],
                        [DNSEvidenceSource class],
                        [LaptopLidEvidenceSource class],
						[LightEvidenceSource class],
						[WiFiEvidenceSourceCoreWLAN class],
						[PowerEvidenceSource class],
						[RunningApplicationEvidenceSource class],
                        [ShellScriptEvidenceSource class],
						[SleepEvidenceSource class],
						[TimeOfDayEvidenceSource class],
						nil];
    
#ifdef DEBUG_MODE
    for (NSString *pluginPath in [self getEvidenceSourcePlugins]) {
        NSLog(@"would load plugin at %@", pluginPath);
        NSBundle *thePlugin = [NSBundle bundleWithPath:pluginPath];
        Class principalClass = [thePlugin principalClass];
        @try {
            [classes addObject:principalClass];
        }
        @catch (NSException *e) {
            NSLog(@"%@ is not a valid plugin", pluginPath);
        }
    }
#endif

	if (NO) {
		// Purely for the benefit of 'genstrings'
        NSLocalizedString(@"AttachedPowerAdapter", @"Evidence source");
		NSLocalizedString(@"AudioOutput", @"Evidence source");
		NSLocalizedString(@"Bluetooth", @"Evidence source");
		NSLocalizedString(@"Bonjour", @"Evidence source");
		NSLocalizedString(@"CoreLocation", @"Evidence source");
		NSLocalizedString(@"FireWire", @"Evidence source");
		NSLocalizedString(@"DNS", @"Evidence source");
		NSLocalizedString(@"IPAddr", @"Evidence source");
		NSLocalizedString(@"Light", @"Evidence source");
		NSLocalizedString(@"Monitor", @"Evidence source");
		NSLocalizedString(@"NetworkLink", @"Evidence source");
		NSLocalizedString(@"Power", @"Evidence source");
		NSLocalizedString(@"RunningApplication", @"Evidence source");
        NSLocalizedString(@"Shell Script", @"Evidence source");
		NSLocalizedString(@"Sleep/Wake", @"Evidence source");
		NSLocalizedString(@"TimeOfDay", @"Evidence source");
		NSLocalizedString(@"USB", @"Evidence source");
        NSLocalizedString(@"WiFi using CoreWLAN", @"Evidence source");
	}

	// Instantiate all the evidence sources if they are supported on this device
	NSMutableArray *srcList = [[NSMutableArray alloc] initWithCapacity:[classes count]];
    NSUInteger ruleTypesMaxCount = 0u;
    for (Class class in classes) {
        if ([class isEvidenceSourceApplicableToSystem]) {
            @autoreleasepool {
                EvidenceSource *src = [[class alloc] init];
                if (!src) {
                    DSLog(@"%@ failed to init properly", class);
                    continue;
                }
                [srcList addObject:src];
                ruleTypesMaxCount += [[src typesOfRulesMatched] count];
                [src release];
            }
        }
    }

	sources = srcList;
    enabledSourcesForRuleTypes = [[NSMutableDictionary alloc] initWithCapacity:ruleTypesMaxCount];
    
	return self;
}

- (void)dealloc {
    for (EvidenceSource *src in sources) {
        [src stop];
    }

    [enabledSourcesForRuleTypes release];
	[sources release];

	[super dealloc];
}

/**
 *  Returns an array containing paths to all of the available Evidence Source Plugins
 */
- (NSArray *)getEvidenceSourcePlugins {
    NSMutableArray *searchPaths = [NSMutableArray array];
    NSMutableArray *bundles = [NSMutableArray array];
    NSString *pluginPath = @"/Application Support/ControlPlane/PlugIns/Evidence Sources";
    
    
    for (NSString *path in NSSearchPathForDirectoriesInDomains(
                                                               NSLibraryDirectory,
                                                               NSAllDomainsMask - NSSystemDomainMask,
                                                               YES)) {
        [searchPaths addObject:[path stringByAppendingPathComponent:pluginPath]];
    }
    
    [searchPaths addObject:[NSString stringWithFormat:@"%@/Evidence Sources",[[NSBundle mainBundle] builtInPlugInsPath]]];
    
    
    for (NSString *currentPath in searchPaths) {
        NSDirectoryEnumerator *dirEnumerator;
        NSString *currentFile;
        
        dirEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:currentPath];
        
        if (dirEnumerator) {
            while (currentFile = [dirEnumerator nextObject]) {
                if([[currentFile pathExtension] isEqualToString:@"bundle"]) {
                    [bundles addObject:[currentPath stringByAppendingPathComponent:currentFile]];
                }
            }
        }
    }
    
    // hand back an immutable version
    return (NSArray *)bundles;
}

- (EvidenceSource *)sourceWithName:(NSString *)name {
	for (EvidenceSource *src in sources) {
		if ([[src name] isEqualToString:name]) {
			return src;
        }
    }
	return nil;
}

- (void)startOrStopAll {
    [enabledSourcesForRuleTypes removeAllObjects];

    // walk through all of the Evidence Sources that are enabled
    // and issue a start on each one
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    @autoreleasepool {
        for (EvidenceSource *src in sources) {
            BOOL enabledByUser = [standardUserDefaults boolForKey:[src enablementKeyName]];

            if ([src isRunning] != enabledByUser) {
                if (enabledByUser) {
                    DSLog(@"Starting %@ evidence source", [src name]);
                    [src start];
                } else {
                    DSLog(@"Stopping %@ evidence source", [src name]);
                    [src stop];
                }
            }
        }
    }
}

- (NSIndexSet *)indexesOfEnabledSourcesForRuleType:(NSString *)ruleType {
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];

    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    [sources enumerateObjectsUsingBlock:^(EvidenceSource *src, NSUInteger idx, BOOL *stop) {
		if ([src matchesRulesOfType:ruleType]) {
            if ([standardUserDefaults boolForKey:[src enablementKeyName]]) { // if enabled
                [indexes addIndex:idx];
            }
        }
    }];

    return indexes;
}

- (RuleMatchStatusType)ruleMatches:(NSMutableDictionary *)rule {
	NSString *ruleType = rule[@"type"];

    NSIndexSet *sourceIndexes = enabledSourcesForRuleTypes[ruleType];
    if (!sourceIndexes) {
        enabledSourcesForRuleTypes[ruleType] = sourceIndexes = [self indexesOfEnabledSourcesForRuleType:ruleType];
    }

    __block RuleMatchStatusType result = RuleMatchStatusIsUnknown;
    [sources enumerateObjectsAtIndexes:sourceIndexes options:0
                            usingBlock:^(EvidenceSource *src, NSUInteger idx, BOOL *stop) {
        if ([src isRunning]) {
#if DEBUG_MODE
            DSLog(@"checking EvidenceSource %@ for matching rules", src);
#endif
            if ([src doesRuleMatch:rule]) {
                result = RuleDoesMatch;
                *stop = YES;
                return;
            }
            
            result = RuleDoesNotMatch;
        }
    }];

	return result;
}

- (NSEnumerator *)sourceEnumerator {
	return [sources objectEnumerator];
}

#pragma mark NSMenu delegates

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(int)index shouldCancel:(BOOL)shouldCancel {
	EvidenceSource *src = sources[index];
    NSString *friendlyName = [src friendlyName];
	[item setTitle:[NSString stringWithFormat:NSLocalizedString(@"Add '%@' Rule...", @"Menu item"),
                    friendlyName]];

    NSArray *typesOfRulesMatched = [src typesOfRulesMatched];
	if ([typesOfRulesMatched count] > 1) {
		NSMenu *submenu = [[NSMenu alloc] init];
		for (NSString *type in typesOfRulesMatched) {
			NSMenuItem *it = [[NSMenuItem alloc] init];
			[it setTitle:NSLocalizedString(type, @"Rule type")];
			[it setTarget:prefsWindowController];
			[it setAction:@selector(addRule:)];
			[it setRepresentedObject:@[src, type]];
			[submenu addItem:it];
            [it release];
		}
		[item setSubmenu:submenu];
        [submenu release];
	} else {
		[item setTarget:prefsWindowController];
		[item setAction:@selector(addRule:)];
		[item setRepresentedObject:src];
	}

	// Bindings
	[item bind:@"enabled" toObject:src withKeyPath:@"dataCollected" options:nil];
	// TODO?: enabled2 -> NSUserDefaults.values.Enable%@EvidenceSource

    [item setHidden:![src isRunning]];

	return YES;
}

- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action {
	// TODO: support keyboard menu jumping?
	return NO;
}

// we're being asked how many items should be in the add new rule menu
// we build a list of the running evidence sources which will be used in
// the '- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(int)index shouldCancel:(BOOL)shouldCancel'
// call which is next
- (NSUInteger)numberOfItemsInMenu:(NSMenu *)menu {
	return [sources count];
}

#pragma mark NSTableViewDataSource protocol methods

- (NSUInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
	return [sources count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
	EvidenceSource *src = sources[rowIndex];
    NSString *friendlyName = [src friendlyName];
	NSString *col_id = [aTableColumn identifier];

	if ([@"enabled" isEqualToString:col_id]) {
		return [[NSUserDefaults standardUserDefaults] valueForKey:[src enablementKeyName]];
	} else if ([@"name" isEqualToString:col_id]) {
		return NSLocalizedString(friendlyName, @"Evidence source");
	}

	// Shouldn't get here!
	return nil;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {

	NSString *col_id = [aTableColumn identifier];
    
	if ([@"enabled" isEqualToString:col_id]) {
        EvidenceSource *src = sources[rowIndex];
		[[NSUserDefaults standardUserDefaults] setValue:anObject forKey:[src enablementKeyName]];
		return;
	}

	// Shouldn't get here!
}

- (NSString *)tableView:(NSTableView *)aTableView toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect
            tableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation {

	NSString *col_id = [aTableColumn identifier];

    if ([@"name" isEqualToString:col_id]) {
        return [sources[row] description];
    }

    return nil; // no tool tip available
}

@end
