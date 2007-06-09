//
//  MailSMTPServerAction.h
//  MarcoPolo
//
//  Created by David Symonds on 3/04/07.
//

#import <Cocoa/Cocoa.h>
#import "Action.h"


@interface MailSMTPServerAction : Action <ActionWithString> {
	NSString *hostname;
}

- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

- (id)initWithString:(NSString *)string;

@end
