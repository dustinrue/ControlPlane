//
//  MailSMTPServerAction.m
//  ControlPlane
//
//  Created by David Symonds on 3/04/07.
//

#import "MailSMTPServerAction.h"
#import <ScriptingBridge/SBApplication.h>
#import "Mail.h"


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

- (BOOL) execute: (NSString **) errorString {
	@try {
		MailApplication *Mail = [SBApplication applicationWithBundleIdentifier: @"com.apple.mail"];
		
		// find SMTP server
		for (MailSmtpServer *server in [Mail smtpServers])
			if ([server.serverName isEqualToString: hostname]) {
				// apply to enabled accounts
				for (MailAccount *account in [Mail accounts])
					if (account.enabled)
						account.deliveryAccount = server;
				
				break;
			}
		
	} @catch (NSException *e) {
		*errorString = NSLocalizedString(@"Couldn't set IMAP server!", @"In MailIMAPServerAction");
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
