//
//  UnmountAction.h
//  ControlPlane
//
//  Created by Mark Wallis on 14/11/07.
//

#import "Action.h"


@interface UnmountAction : Action <ActionWithString> {
	NSString *path;
}

- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

@end
