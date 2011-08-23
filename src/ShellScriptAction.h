//
//  ShellScriptAction.h
//  ControlPlane
//
//  Created by David Symonds on 23/04/07.
//

#import <Cocoa/Cocoa.h>
#import "Action.h"


@interface ShellScriptAction : Action <ActionWithFileParameter> {
	NSString *path;
}

- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;

- (id)initWithFile:(NSString *)file;

@end
