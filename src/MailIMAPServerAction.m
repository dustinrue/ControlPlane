//
//  MailIMAPServerAction.m
//  MarcoPolo
//
//  Created by David Symonds on 10/08/07.
//

#import "MailIMAPServerAction.h"


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

- (BOOL)execute:(NSString **)errorString
{
	NSString *script = [NSString stringWithFormat:
		@"tell application \"Mail\"\n"
		"  repeat with acc in every imap account\n"
		"    set the server name of acc to \"%@\"\n"
		"  end repeat\n"
		"end tell\n", hostname];

	if (![self executeAppleScript:script]) {
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
