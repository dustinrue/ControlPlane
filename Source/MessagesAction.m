//
//  MessagesAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 6/23/12.
//
//

#import "MessagesAction.h"
#import "Messages.h"
#import "DSLogger.h"

@implementation MessagesAction

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
	return [NSString stringWithFormat:NSLocalizedString(@"Setting Messages/iChat status to '%@'.", @""), status];
}

- (BOOL) execute: (NSString **) errorString {
	@try {
		MessagesApplication *Messages = [SBApplication applicationWithBundleIdentifier: @"com.apple.iChat"];
		
		// set status message
		Messages.statusMessage = status;
		
	} @catch (NSException *e) {
		DSLog(@"Exception: %@", e);
		*errorString = NSLocalizedString(@"Couldn't set Messages/iChat status!", @"In MessagesAction");
		return NO;
	}
	
	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for Messages/iChat actions is the status message to set.", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Set Messages/iChat status message to", @"");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Messages/iChat Status", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Applications", @"");
}

@end
