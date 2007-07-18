//
//  Action.m
//  MarcoPolo
//
//  Created by David Symonds on 3/04/07.
//

#import "Action.h"


@implementation Action

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
		NSLog(@"ERROR: No implementation class '%@'!\n", classString);
		return nil;
	}
	return klass;
}

+ (Action *)actionFromDictionary:(NSDictionary *)dict
{
	NSString *type = [dict valueForKey:@"type"];
	if (!type) {
		NSLog(@"ERROR: Action doesn't have a type!\n");
		return nil;
	}
	Action *obj = [[[Action classForType:type] alloc] initWithDictionary:dict];
	return [obj autorelease];
}

- (id)init
{
	if ([[self class] isEqualTo:[Action class]]) {
		[NSException raise:@"Abstract Class Exception"
			    format:@"Error, attempting to instantiate Action directly."];
	}

	if (!(self = [super init]))
		return nil;

	// Some sensible defaults
	delay = 0;
	type = [[Action typeForClass:[self class]] retain];
	context = [@"" retain];
	when = [@"Arrival" retain];
	enabled = [[NSNumber alloc] initWithBool:YES];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if ([[self class] isEqualTo:[Action class]]) {
		[NSException raise:@"Abstract Class Exception"
			    format:@"Error, attempting to instantiate Action directly."];
	}

	if (!(self = [super init]))
		return nil;

	delay = [[dict valueForKey:@"delay"] intValue];
	type = [[Action typeForClass:[self class]] retain];
	context = [[dict valueForKey:@"context"] copy];
	when = [[dict valueForKey:@"when"] copy];
	enabled = [[dict valueForKey:@"enabled"] copy];

	return self;
}

- (void)dealloc
{
	[type release];
	[context release];
	[when release];
	[enabled release];

	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	return [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:delay], @"delay",
		[[type copy] autorelease], @"type",
		[[context copy] autorelease], @"context",
		[[when copy] autorelease], @"when",
		[[enabled copy] autorelease], @"enabled",
		nil];
}

+ (NSString *)helpTextForActionOfType:(NSString *)type
{
	return [[Action classForType:type] helpText];
}

- (void)notImplemented:(NSString *)methodName
{
	[NSException raise:@"Abstract Class Exception"
		    format:[NSString stringWithFormat:@"Error, -[%@ %@] not implemented.",
			    [self class], methodName]];
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

@end

#pragma mark -

#import "DefaultPrinterAction.h"
#import "FirewallRuleAction.h"
#import "IChatAction.h"
#import "MailSMTPServerAction.h"
#import "MountAction.h"
#import "MuteAction.h"
#import "NetworkLocationAction.h"
#import "OpenAction.h"
#import "ScreenSaverPasswordAction.h"
#import "ScreenSaverTimeAction.h"
#import "ShellScriptAction.h"
#import "ToggleBluetoothAction.h"
#import "ToggleWiFiAction.h"

@implementation ActionSetController

- (id)init
{
	if (!(self = [super init]))
		return nil;

	classes = [[NSArray alloc] initWithObjects:
		[DefaultPrinterAction class],
		[FirewallRuleAction class],
		[IChatAction class],
		[MailSMTPServerAction class],
		[MountAction class],
		[MuteAction class],
		[NetworkLocationAction class],
		[OpenAction class],
		[ScreenSaverPasswordAction class],
		[ScreenSaverTimeAction class],
		[ShellScriptAction class],
		[ToggleBluetoothAction class],
		[ToggleWiFiAction class],
			nil];
	if (NO) {
		// Purely for the benefit of 'genstrings'
		NSLocalizedString(@"DefaultPrinter", @"Action type");
		NSLocalizedString(@"FirewallRule", @"Action type");
		NSLocalizedString(@"IChat", @"Action type");
		NSLocalizedString(@"MailSMTPServer", @"Action type");
		NSLocalizedString(@"Mount", @"Action type");
		NSLocalizedString(@"Mute", @"Action type");
		NSLocalizedString(@"NetworkLocation", @"Action type");
		NSLocalizedString(@"Open", @"Action type");
		NSLocalizedString(@"ScreenSaverPassword", @"Action type");
		NSLocalizedString(@"ScreenSaverTime", @"Action type");
		NSLocalizedString(@"ShellScript", @"Action type");
		NSLocalizedString(@"ToggleBluetooth", @"Action type");
		NSLocalizedString(@"ToggleWiFi", @"Action type");
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
		[array addObject:[Action typeForClass:klass]];
	}
	return array;
}

#pragma mark NSMenu delegates

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(int)index shouldCancel:(BOOL)shouldCancel
{
	Class klass = [classes objectAtIndex:index];
	NSString *type = [Action typeForClass:klass];
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

- (int)numberOfItemsInMenu:(NSMenu *)menu
{
	return [classes count];
}

@end
