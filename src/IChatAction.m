//
//  IChatAction.m
//  ControlPlane
//
//  Created by David Symonds on 8/06/07.
//

#import "IChatAction.h"
#import <ScriptingBridge/SBApplication.h>
#import "iChat.h"

@implementation IChatAction

- (id)init
{
	if (!(self = [super init]))
		return nil;

	status = [[NSString alloc] init];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super initWithDictionary:dict]))
		return nil;

	status = [[dict valueForKey:@"parameter"] copy];

	return self;
}

- (void)dealloc
{
	[status release];

	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];

	[dict setObject:[[status copy] autorelease] forKey:@"parameter"];

	return dict;
}

- (NSString *)description
{
	return [NSString stringWithFormat:NSLocalizedString(@"Setting iChat status to '%@'.", @""), status];
}

- (BOOL) execute: (NSString **) errorString {
	@try {
		iChatApplication *iChat = [SBApplication applicationWithBundleIdentifier: @"com.apple.iChat"];
		
		// set status message
		iChat.statusMessage = status;
		
	} @catch (NSException *e) {
		*errorString = NSLocalizedString(@"Couldn't set iChat status!", @"In IChatAction");
		return NO;
	}
	
	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for iChat actions is the status message to set.", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Set iChat status message to", @"");
}

@end
