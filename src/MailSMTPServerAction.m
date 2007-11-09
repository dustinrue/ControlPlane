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
		"      set smtp server of every account to server\n"
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

	NSTask *task = [[[NSTask alloc] init] autorelease];

	[task setLaunchPath:@"/usr/bin/osascript"];
	[task setArguments:[NSArray arrayWithObjects:@"-e", script, nil]];
	[task setStandardOutput:[NSPipe pipe]];

	[task launch];
	NSData *data = [[[task standardOutput] fileHandleForReading] readDataToEndOfFile];
	[task waitUntilExit];
	if ([task terminationStatus] != 0)	// failure
		return [NSArray array];
	// XXX: what's the proper string encoding here?
	NSString *s_data = [[[NSString alloc] initWithData:data encoding:NSMacOSRomanStringEncoding] autorelease];
	if ([s_data hasSuffix:@"\n"] || [s_data hasSuffix:@"\r"])
		s_data = [s_data substringToIndex:[s_data length] - 1];
	NSArray *lines = [s_data componentsSeparatedByString:@","];

	NSMutableArray *opts = [NSMutableArray arrayWithCapacity:[lines count]];
	NSEnumerator *en = [lines objectEnumerator];
	NSString *bit;
	while ((bit = [en nextObject])) {
		NSString *hostname = [[bit componentsSeparatedByString:@" "] lastObject];
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
