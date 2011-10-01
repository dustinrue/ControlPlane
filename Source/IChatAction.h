//
//  IChatAction.h
//  ControlPlane
//
//  Created by David Symonds on 8/06/07.
//

#import "CAction.h"


@interface IChatAction : CAction <ActionWithString> {
	NSString *status;
}

- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

@end
