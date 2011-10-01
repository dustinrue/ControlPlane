//
//  MailSMTPServerAction.h
//  ControlPlane
//
//  Created by David Symonds on 3/04/07.
//

#import "CAction.h"


@interface MailSMTPServerAction : CAction <ActionWithLimitedOptions> {
	NSString *hostname;
}

- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

+ (NSArray *)limitedOptions;
- (id)initWithOption:(NSString *)option;

@end
