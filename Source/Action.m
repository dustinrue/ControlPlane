//
//  Action.m
//  ControlPlane
//
//  Created by David Symonds on 3/04/07.
//

#import "Action.h"
#import "PrefsWindowController.h"

@implementation CAction

+ (NSString *)typeForClass:(Class)klass
{
	// Hack "Action" off class name (6 chars)
	// TODO: make this a bit more robust?
	NSString *className = NSStringFromClass(klass);
	return [className substringToIndex:([className length] - 6)];
}

+ (Class)classForType:(NSString *)type
{
	NSString *classString = [NSString stringWithFormat:@"%@Action", type];
	Class klass = NSClassFromString(classString);
	if (!klass) {
		LogError_Action(@"ERROR: No implementation class '%@'!", classString);
		return nil;
	}
	return klass;
}

+ (CAction *)actionFromDictionary:(NSDictionary *)dict
{
	NSString *type = [dict valueForKey:@"type"];
	if (!type) {
		LogError_Action(@"ERROR: Action doesn't have a type!");
		return nil;
	}
	CAction *obj = [[[CAction classForType:type] alloc] initWithDictionary:dict];
	return [obj autorelease];
}

- (id)init
{
	if ([[self class] isEqualTo:[CAction class]]) {
		[NSException raise:@"Abstract Class Exception"
			    format:@"Error, attempting to instantiate Action directly."];
	}

	if (!(self = [super init]))
		return nil;
	
	// Some sensible defaults
	type = [[CAction typeForClass:[self class]] retain];
	context = [@"" retain];
	when = [@"Arrival" retain];
	delay = [[NSNumber alloc] initWithDouble:0];
	enabled = [[NSNumber alloc] initWithBool:YES];
	
	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if ([[self class] isEqualTo:[CAction class]]) {
		[NSException raise:@"Abstract Class Exception"
			    format:@"Error, attempting to instantiate Action directly."];
	}

	if (!(self = [super init]))
		return nil;

	type = [[CAction typeForClass:[self class]] retain];
	context = [[dict valueForKey:@"context"] copy];
	when = [[dict valueForKey:@"when"] copy];
	delay = [[dict valueForKey:@"delay"] copy];
	enabled = [[dict valueForKey:@"enabled"] copy];

	return self;
}

- (void)dealloc
{
	[type release];
	[context release];
	[when release];
	[delay release];
	[enabled release];

	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	return [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[[type copy] autorelease], @"type",
		[[context copy] autorelease], @"context",
		[[when copy] autorelease], @"when",
		[[delay copy] autorelease], @"delay",
		[[enabled copy] autorelease], @"enabled",
		nil];
}

+ (NSString *)helpTextForActionOfType:(NSString *)type
{
	return [[CAction classForType:type] helpText];
}

- (NSComparisonResult)compareDelay:(CAction *)other
{
	return [[self valueForKey:@"delay"] compare:[other valueForKey:@"delay"]];
}

- (void)notImplemented:(NSString *)methodName
{
	[NSException raise:@"Abstract Class Exception"
		    format:@"Error, -[%@ %@] not implemented.",
			    [self class], methodName];
}

- (NSString *)description
{
	[self notImplemented:@"description"];
	return @"Not implemented!";
}

- (BOOL)execute:(NSString **)errorString
{
	[self notImplemented:@"execute"];
	*errorString = @"Not implemented!";
	return NO;
}

+ (NSString *)helpText
{
	return @"Sorry, no help text written yet!";
}

+ (NSString *)creationHelpText
{
	return @"<Sorry, help text coming soon!>";
}

- (void)executeAppleScriptForReal:(NSString *)script
{
	appleScriptResult_ = nil;
    
	NSAppleScript *as = [[[NSAppleScript alloc] initWithSource:script] autorelease];
	if (!as) {
		NSLog(@"AppleScript failed to construct! Script was:\n%@", script);
		return;
	}
	NSDictionary *errorDict;
	if (![as compileAndReturnError:&errorDict]) {
		NSLog(@"AppleScript failed to compile! Script was:\n%@\nError dictionary: %@", script, errorDict);
		return;
	}
	appleScriptResult_ = [as executeAndReturnError:&errorDict];
	if (!appleScriptResult_)
		NSLog(@"AppleScript failed to execute! Script was:\n%@\nError dictionary: %@", script, errorDict);
}

- (BOOL)executeAppleScript:(NSString *)script
{
	// NSAppleScript is not thread-safe, so this needs to happen on the main thread. Ick.
	[self performSelectorOnMainThread:@selector(executeAppleScriptForReal:)
                           withObject:script
                        waitUntilDone:YES];
	return (appleScriptResult_ ? YES : NO);
}

- (NSArray *)executeAppleScriptReturningListOfStrings:(NSString *)script
{
	if (![self executeAppleScript:script])
		return nil;
	if ([appleScriptResult_ descriptorType] != typeAEList)
		return nil;
    
	NSInteger count = [appleScriptResult_ numberOfItems];
	NSMutableArray *list = [NSMutableArray arrayWithCapacity: (NSUInteger) count];
	for (NSInteger i = 1; i <= count; ++i) {		// Careful -- AppleScript lists are 1-based
		NSAppleEventDescriptor *elt = [appleScriptResult_ descriptorAtIndex:i];
		if (!elt) {
			NSLog(@"Oops -- couldn't get descriptor at index %ld", i);
			continue;
		}
		NSString *val = [elt stringValue];
		if (!val) {
			NSLog(@"Oops -- couldn't turn descriptor at index %ld into string", i);
			continue;
		}
		[list addObject:val];
	}
    
	return list;
}

@end

#pragma mark -

@implementation ActionSetController

- (id)init
{
	if (!(self = [super init]))
		return nil;

	classes = [NSArray new];
	
	if (NO) {
		// Purely for the benefit of 'genstrings'
		NSLocalizedString(@"DefaultBrowser", @"Action type");
        NSLocalizedString(@"DefaultPrinter", @"Action type");
		NSLocalizedString(@"DesktopBackground", @"Action type");
		NSLocalizedString(@"DisplayBrightness", @"Action type");
		NSLocalizedString(@"FirewallRule", @"Action type");
		NSLocalizedString(@"iChat", @"Action type");
		NSLocalizedString(@"iTunesPlaylist", @"Action type");
		NSLocalizedString(@"LockKeychain", @"Action type");
		NSLocalizedString(@"MailIMAPServer", @"Action type");
		NSLocalizedString(@"MailSMTPServer", @"Action type");
		NSLocalizedString(@"MailInterval", @"Action type");
		NSLocalizedString(@"Mount", @"Action type");
		NSLocalizedString(@"Mute", @"Action type");
		NSLocalizedString(@"NetworkLocation", @"Action type");
		NSLocalizedString(@"Open", @"Action type");
		NSLocalizedString(@"OpenURL", @"Action type");
		NSLocalizedString(@"QuitApplication", @"Action type");
		NSLocalizedString(@"ScreenSaverPassword", @"Action type");
		NSLocalizedString(@"ScreenSaverStart", @"Action type");
		NSLocalizedString(@"ScreenSaverTime", @"Action type");
		NSLocalizedString(@"ShellScript", @"Action type");
		NSLocalizedString(@"Speak", @"Action type");
		NSLocalizedString(@"StartTimeMachine", @"Action type");
        NSLocalizedString(@"TimeMachineDestination", @"Action type");
		NSLocalizedString(@"ToggleBluetooth", @"Action type");
		NSLocalizedString(@"ToggleFirewall", @"Action type");
		NSLocalizedString(@"ToggleInternetSharing", @"Action type");
        NSLocalizedString(@"TimeMachineAction",@"Action type");
		NSLocalizedString(@"ToggleWiFi", @"Action type");
		NSLocalizedString(@"Unmount", @"Action type");
		NSLocalizedString(@"VPN", @"Action type");
	}

	return self;
}

- (void)dealloc
{
	[classes release];

	[super dealloc];
}

- (NSArray *)types
{
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[classes count]];
	NSEnumerator *en = [classes objectEnumerator];
	Class klass;
	while ((klass = [en nextObject])) {
		[array addObject:[CAction typeForClass:klass]];
	}
	return array;
}

#pragma mark NSMenu delegates

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(int)index shouldCancel:(BOOL)shouldCancel
{
	Class klass = [classes objectAtIndex: (NSUInteger) index];
	NSString *type = [CAction typeForClass:klass];
	NSString *localisedType = NSLocalizedString(type, @"Action type");

	NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Add %@ Action...", @"Menu item"),
		localisedType];
	[item setTitle:title];

	[item setTarget:prefsWindowController];
	[item setAction:@selector(addAction:)];
	[item setRepresentedObject:klass];

	return YES;
}

- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action
{
	// TODO: support keyboard menu jumping?
	return NO;
}

- (NSUInteger)numberOfItemsInMenu:(NSMenu *)menu
{
	return [classes count];
}

@end
