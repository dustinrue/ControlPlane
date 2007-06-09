//
//  MailSMTPServerAction.m
//  MarcoPolo
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
	if (!(self = [super init]))
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
		"      set smtp server of every account to server\n"
		"      exit repeat\n"
		"    end if\n"
		"  end repeat\n"
		"end tell\n", hostname];
	NSArray *args = [NSArray arrayWithObjects:@"-e", script, nil];
	NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/osascript" arguments:args];
	[task waitUntilExit];

	if ([task terminationStatus] != 0) {
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

@end
