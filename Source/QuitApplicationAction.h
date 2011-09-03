//
//  QuitApplicationAction.h
//  ControlPlane
//
//  Created by David Symonds on 15/10/07.
//

#import "Action.h"


@interface QuitApplicationAction : Action <ActionWithString> {
	NSString *application;
}

- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

@end
