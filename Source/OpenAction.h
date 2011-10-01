//
//  OpenAction.h
//  ControlPlane
//
//  Created by David Symonds on 3/04/07.
//

#import "CAction.h"


@interface OpenAction : CAction <ActionWithFileParameter> {
	NSString *path;
}

- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;

- (id)initWithFile:(NSString *)file;

@end
