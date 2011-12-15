//
//  MailIMAPServerAction.m
//  ControlPlane
//
//  Created by David Symonds on 10/08/07.
//

#import "MailIMAPServerAction.h"
#import <ScriptingBridge/SBApplication.h>
#import "Mail.h"
#import "DSLogger.h"

@implementation MailIMAPServerAction

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
	return [NSString stringWithFormat:NSLocalizedString(@"Setting Mail's IMAP server to '%@'.", @""),
		hostname];
}

- (BOOL) execute: (NSString **) errorString {
	@try {
		MailApplication *Mail = [SBApplication applicationWithBundleIdentifier: @"com.apple.mail"];
		
		// for every IMAP account
		for (MailImapAccount *account in [Mail imapAccounts])
			account.serverName = hostname;
		
	} @catch (NSException *e) {
		DSLog(@"Exception: %@", e);
		*errorString = NSLocalizedString(@"Couldn't set IMAP server!", @"In MailIMAPServerAction");
		return NO;
	}
	
	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for MailIMAPServer actions is the hostname of the "
				 "IMAP server to make the default for all Mail accounts.", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Set Mail's IMAP server hostname to", @"");
}

@end
