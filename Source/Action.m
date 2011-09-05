//
//  Action.m
//  ControlPlane
//
//  Created by David Symonds on 3/04/07.
//

#import "Action.h"
#import "BetterAuthorizationSampleLib.h"
#import "DSLogger.h"
#import "PrefsWindowController.h"
#import <libkern/OSAtomic.h>

extern const BASCommandSpec kCPHelperToolCommandSet[];

@interface Action (Private)

- (OSStatus) helperToolActualPerform: (NSString *) action withResponse: (CFDictionaryRef *) response andAuth: (AuthorizationRef) auth;
- (void) helperToolInit: (AuthorizationRef *) auth;
- (OSStatus) helperToolFix: (BASFailCode) failCode withAuth: (AuthorizationRef) auth;
- (void) helperToolAlert: (NSMutableDictionary *) parameters;

@end

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
		NSLog(@"ERROR: No implementation class '%@'!", classString);
		return nil;
	}
	return klass;
}

+ (Action *)actionFromDictionary:(NSDictionary *)dict
{
	NSString *type = [dict valueForKey:@"type"];
	if (!type) {
		NSLog(@"ERROR: Action doesn't have a type!");
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
	type = [[Action typeForClass:[self class]] retain];
	context = [@"" retain];
	when = [@"Arrival" retain];
	delay = [[NSNumber alloc] initWithDouble:0];
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

	type = [[Action typeForClass:[self class]] retain];
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
	return [[Action classForType:type] helpText];
}

- (NSComparisonResult)compareDelay:(Action *)other
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

#pragma mark HelperTool methods

- (BOOL) helperToolPerformAction: (NSString *) action {
	static int32_t versionCheck = 0;
	
	CFDictionaryRef response = NULL;
	AuthorizationRef auth = NULL;
	OSStatus error = noErr;
	
	// initialize
	[self helperToolInit: &auth];
	
	if (!versionCheck) {
		// start version check
		OSAtomicIncrement32(&versionCheck);
		
		// get version of helper tool
		error = [self helperToolActualPerform: @kCPHelperToolGetVersionCommand withResponse: &response andAuth: auth];
		if (error) {
			OSAtomicDecrement32(&versionCheck);
			return NO;
		}
		
		// check version and update if needed
		NSNumber *version = [(NSDictionary *) response objectForKey: @kCPHelperToolGetVersionResponse];
		if ([version intValue] < kCPHelperToolVersionNumber)
			[self helperToolFix: kBASFailNeedsUpdate withAuth: auth];
		
		// finish version check
		OSAtomicIncrement32(&versionCheck);
	}
	
	//  wait until version check is done
	while (versionCheck < 2)
		[NSThread sleepForTimeInterval: 1];
	
	// perform actual action
	error = [self helperToolActualPerform: (NSString *) action withResponse: &response andAuth: auth];
	
	return (error ? NO : YES);
}

- (OSStatus) helperToolActualPerform: (NSString *) action
						withResponse: (CFDictionaryRef *) response
							 andAuth: (AuthorizationRef) auth {
	
	NSString *bundleID;
	NSDictionary *request;
	OSStatus error = 0;
	*response = NULL;

	// create request
	bundleID = [[NSBundle mainBundle] bundleIdentifier];
	assert(bundleID != NULL);
	request = [NSDictionary dictionaryWithObjectsAndKeys: action, @kBASCommandKey, nil];
	assert(request != NULL);

	// Execute it.
	error = BASExecuteRequestInHelperTool(auth,
										  kCPHelperToolCommandSet, 
										  (CFStringRef) bundleID, 
										  (CFDictionaryRef) request,
										  response);

	// If it failed, try to recover.
	if (error != noErr && error != userCanceledErr) {
		BASFailCode failCode = BASDiagnoseFailure(auth, (CFStringRef) bundleID);
		
		// try to fix
		error = [self helperToolFix: failCode withAuth: auth];
		
		// If the fix went OK, retry the request.
		if (error == noErr)
			error = BASExecuteRequestInHelperTool(auth,
												  kCPHelperToolCommandSet,
												  (CFStringRef) bundleID,
												  (CFDictionaryRef) request,
												  response);
	}

	// If all of the above went OK, it means that the IPC to the helper tool worked.  We 
	// now have to check the response dictionary to see if the command's execution within 
	// the helper tool was successful.

	if (error == noErr)
		error = BASGetErrorFromResponse(*response);
	
	return error;
}

- (void) helperToolInit: (AuthorizationRef *) auth {
	OSStatus err = 0;

	// Create the AuthorizationRef that we'll use through this application.  We ignore 
	// any error from this.  A failure from AuthorizationCreate is very unusual, and if it 
	// happens there's no way to recover; Authorization Services just won't work.

	err = AuthorizationCreate(NULL, NULL, kAuthorizationFlagDefaults, auth);
	assert(err == noErr);
	assert((err == noErr) == (*auth != NULL));

	// For each of our commands, check to see if a right specification exists and, if not,
	// create it.
	//
	// The last parameter is the name of a ".strings" file that contains the localised prompts 
	// for any custom rights that we use.

	BASSetDefaultRules(*auth, 
					   kCPHelperToolCommandSet, 
					   CFBundleGetIdentifier(CFBundleGetMainBundle()), 
					   CFSTR("CPHelperToolAuthorizationPrompts"));
}

- (OSStatus) helperToolFix: (BASFailCode) failCode withAuth: (AuthorizationRef) auth {
	NSMutableDictionary *parameters = [[[NSMutableDictionary alloc] init] autorelease];
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
	OSStatus err = noErr;
	
	// At this point we tell the user that something has gone wrong and that we need 
	// to authorize in order to fix it.  Ideally we'd use failCode to describe the type of 
	// error to the user.
	
	[self performSelectorOnMainThread: @selector(helperToolAlert:) withObject: parameters waitUntilDone: YES];
	err = [[parameters objectForKey: @"result"] intValue];
	
	// Try to fix things.
	if (err == NSAlertDefaultReturn) {
		err = BASFixFailure(auth, (CFStringRef) bundleID, CFSTR("CPHelperInstallTool"), CFSTR("CPHelperTool"), failCode);
	} else
		err = userCanceledErr;

	return err;
}

- (void) helperToolAlert: (NSMutableDictionary *) parameters {
	NSInteger t = NSRunAlertPanel(NSLocalizedString(@"ControlPlane Helper Needed", @"Fix helper tool"),
								   NSLocalizedString(@"ControlPlane needs to install a helper app to enable and disable Time Machine", @"Fix helper tool"),
								   NSLocalizedString(@"Install", @"Fix helper tool"),
								   NSLocalizedString(@"Cancel", @"Fix helper tool"),
								   NULL);
	
	[parameters setObject: [NSNumber numberWithInteger: t] forKey: @"result"];
}

@end

#pragma mark -

#import "DefaultPrinterAction.h"
#import "DefaultBrowserAction.h"
#import "DesktopBackgroundAction.h"
#import "DisplayBrightnessAction.h"
#import "FirewallRuleAction.h"
#import "IChatAction.h"
#import "ITunesPlaylistAction.h"
#import "LockKeychainAction.h"
#import "MailIMAPServerAction.h"
#import "MailSMTPServerAction.h"
#import "MailIntervalAction.h"
#import "MountAction.h"
#import "MuteAction.h"
#import "NetworkLocationAction.h"
#import "OpenAction.h"
#import "OpenURLAction.h"
#import "QuitApplicationAction.h"
#import "ScreenSaverPasswordAction.h"
#import "ScreenSaverStartAction.h"
#import "ScreenSaverTimeAction.h"
#import "ShellScriptAction.h"
#import "SpeakAction.h"
#import "StartTimeMachineAction.h"
#import "ToggleBluetoothAction.h"
#import "ToggleWiFiAction.h"
#import "UnmountAction.h"
#import "VPNAction.h"
#import "ToggleTimeMachineAction.h"

@implementation ActionSetController

- (id)init
{
	if (!(self = [super init]))
		return nil;

	classes = [[NSArray alloc] initWithObjects:
			   [DefaultPrinterAction class],
			   [DefaultBrowserAction class],
			   [DesktopBackgroundAction class],
			   [DisplayBrightnessAction class],
			   [FirewallRuleAction class],
			   [IChatAction class],
			   [ITunesPlaylistAction class],
			   [LockKeychainAction class],
			   [MailIMAPServerAction class],
			   [MailSMTPServerAction class],
			   [MailIntervalAction class],
			   [MountAction class],
			   [MuteAction class],
			   [NetworkLocationAction class],
			   [OpenAction class],
			   [OpenURLAction class],
			   [QuitApplicationAction class],
			   [ScreenSaverPasswordAction class],
			   [ScreenSaverStartAction class],
			   [ScreenSaverTimeAction class],
			   [ShellScriptAction class],
			   [SpeakAction class],
			   [StartTimeMachineAction class],
			   [ToggleBluetoothAction class],
               [ToggleTimeMachineAction class],
			   [ToggleWiFiAction class],
			   [UnmountAction class],
			   [VPNAction class],
			nil];
	
	if (NO) {
		// Purely for the benefit of 'genstrings'
		NSLocalizedString(@"DefaultPrinter", @"Action type");
		NSLocalizedString(@"DefaultBrowser", @"Action type");
		NSLocalizedString(@"DesktopBackground", @"Action type");
		NSLocalizedString(@"DisplayBrightness", @"Action type");
		NSLocalizedString(@"FirewallRule", @"Action type");
		NSLocalizedString(@"IChat", @"Action type");
		NSLocalizedString(@"ITunesPlaylist", @"Action type");
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
		NSLocalizedString(@"ToggleBluetooth", @"Action type");
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

- (NSUInteger)numberOfItemsInMenu:(NSMenu *)menu
{
	return [classes count];
}

@end
