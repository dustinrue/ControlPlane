//
//  MailIMAPServerAction.h
//  ControlPlane
//
//  Created by David Symonds on 10/08/07.
//

#import <Cocoa/Cocoa.h>
#import "Action.h"


@interface MailIMAPServerAction : Action <ActionWithString> {
	NSString *hostname;
}

- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

@end
