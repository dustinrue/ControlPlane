//
//  ShellScriptAction.h
//  ControlPlane
//
//  Created by David Symonds on 23/04/07.
//

#import "Action.h"


@interface ShellScriptAction : Action <ActionWithFileParameter>

- (id)initWithDictionary:(NSDictionary *)dict;
- (id)initWithFile:(NSString *)file;

- (NSMutableDictionary *)dictionary;

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;

@end
