//
//  MountAction.h
//  ControlPlane
//
//  Created by David Symonds on 9/06/07.
//

#import "CAction.h"


@interface MountAction : CAction <ActionWithString> {
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
