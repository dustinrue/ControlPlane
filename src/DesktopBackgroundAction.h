//
//  DesktopBackgroundAction.h
//  MarcoPolo
//
//  Created by David Symonds on 12/11/07.
//

#import <Cocoa/Cocoa.h>
#import "Action.h"


@interface DesktopBackgroundAction : Action <ActionWithFileParameter> {
	NSString *path;
}

- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;

- (id)initWithFile:(NSString *)file;

@end
