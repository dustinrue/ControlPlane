//
//  MailSMTPServerAction.m
//  ControlPlane
//
//  Created by David Symonds on 3/04/07.
//

#import "MailSMTPServerAction.h"


@implementation MailSMTPServerAction

- (id)init
{
	if (!(self = [super init]))
		return nil;

	hostname = [[NSString alloc] init];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super initWithDictionary:dict]))
		return nil;

	hostname = [[dict valueForKey:@"parameter"] copy];

	return self;
}

- (void)dealloc
{
	[hostname release];

	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];

	[dict setObject:[[hostname copy] autorelease] forKey:@"parameter"];

	return dict;
}

- (NSString *)description
{
	return [NSString stringWithFormat:NSLocalizedString(@"Setting Mail's SMTP server to '%@'.", @""),
		hostname];
}

- (BOOL)execute:(NSString **)errorString
{
	NSString *script = [NSString stringWithFormat:
		@"tell application \"Mail\"\n"
		"  repeat with server in every smtp server\n"
		"    if (server name of server is equal to \"%@\") then\n"
		"      repeat with acc in every account\n"
		"        if acc is enabled then\n"
		"          set smtp server of acc to server\n"
		"        end if\n"
		"      end repeat\n"
		"      exit repeat\n"
		"    end if\n"
		"  end repeat\n"
		"end tell\n", hostname];

	if (![self executeAppleScript:script]) {
		*errorString = NSLocalizedString(@"Couldn't set SMTP server!", @"In MailSMTPServerAction");
		return NO;
	}

	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for MailSMTPServer actions is the hostname of the "
				 "SMTP server to make the default for all Mail accounts.", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Set Mail's SMTP server hostname to", @"");
}

+ (NSArray *)limitedOptions
{
	NSString *script =
		@"tell application \"Mail\"\n"
		"  get server name of every smtp server\n"
		"end tell\n";

	NSArray *list = [[[self new] autorelease] executeAppleScriptReturningListOfStrings:script];
	if (!list)		// failure
		return [NSArray array];

	NSMutableArray *opts = [NSMutableArray arrayWithCapacity:[list count]];
	NSEnumerator *en = [list objectEnumerator];
	NSString *hostname;
	while ((hostname = [en nextObject])) {
		[opts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			hostname, @"option", hostname, @"description", nil]];
	}

	return opts;
}

- (id)initWithOption:(NSString *)option
{
	[self init];
	[hostname autorelease];
	hostname = [option copy];
	return self;
}

@end
