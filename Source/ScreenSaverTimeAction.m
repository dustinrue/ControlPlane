//
//  ScreenSaverTimeAction.m
//  ControlPlane
//
//  Created by David Symonds on 7/16/07.
//

#import "ScreenSaverTimeAction.h"


@implementation ScreenSaverTimeAction

- (id)init
{
	if (!(self = [super init]))
		return nil;

	time = [[NSNumber alloc] initWithInt:0];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super initWithDictionary:dict]))
		return nil;

	time = [[dict valueForKey:@"parameter"] copy];

	return self;
}

- (void)dealloc
{
	[time release];

	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];

	[dict setObject:[[time copy] autorelease] forKey:@"parameter"];

	return dict;
}

- (NSString *)description
{
	int t = [time intValue];

	if (t == 0)
		return NSLocalizedString(@"Disabling screen saver.", @"");
	else if (t == 1)
		return NSLocalizedString(@"Setting screen saver idle time to 1 minute.", @"");
	else
		return [NSString stringWithFormat:NSLocalizedString(@"Setting screen saver idle time to %d minutes.", @""), t];
}

- (BOOL)execute:(NSString **)errorString
{
	NSNumber *n = [NSNumber numberWithInt:[time intValue] * 60];	// minutes -> seconds

	CFPreferencesSetValue(CFSTR("idleTime"), (CFPropertyListRef) n,
			      CFSTR("com.apple.screensaver"),
			      kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
	BOOL success = CFPreferencesSynchronize(CFSTR("com.apple.screensaver"),
				 kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);

	// Notify login process
	if (success) {
		CFMessagePortRef port = CFMessagePortCreateRemote(NULL, CFSTR("com.apple.loginwindow.notify"));
        if (port) {
            success = (CFMessagePortSendRequest(port, 500, 0, 0, 0, 0, 0) == kCFMessagePortSuccess);
            CFRelease(port);
        }
	}

	if (!success) {
		*errorString = NSLocalizedString(@"Failed setting screen saver idle time!", @"");
		return NO;
	}

	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for ScreenSaverTimeAction actions is the idle time "
				 "(in minutes) before you want your screen saver to activate.", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Set screen saver idle time to", @"");
}

+ (NSArray *)limitedOptions
{
	int opts[] = { 3, 5, 15, 30, 60, 120, 0 };
	int num_opts = sizeof(opts) / sizeof(opts[0]);
	NSMutableArray *arr = [NSMutableArray arrayWithCapacity:num_opts];

	int i;
	for (i = 0; i < num_opts; ++i) {
		NSNumber *option = [NSNumber numberWithInt:opts[i]];
		NSString *description;

		if (opts[i] == 0)
			description = NSLocalizedString(@"never", @"Screen saver idle time");
		else if (opts[i] == 1)
			description = NSLocalizedString(@"1 minute", @"Screen saver idle time");
		else
			description = [NSString stringWithFormat:NSLocalizedString(@"%d minutes", @"Screen saver idle time"), opts[i]];

		[arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			option, @"option",
			description, @"description", nil]];
	}

	return arr;
}

- (id)initWithOption:(NSString *)option
{
	if (!(self = [super init]))
		return nil;

	[time autorelease];
	time = [[NSNumber alloc] initWithInt:[option intValue]];

	return self;
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Screen Saver Time" , @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"System Preferences", @"");
}

@end
