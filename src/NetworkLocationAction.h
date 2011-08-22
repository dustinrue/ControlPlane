//
//  NetworkLocationAction.h
//  ControlPlane
//
//  Created by David Symonds on 4/07/07.
//

#import <Cocoa/Cocoa.h>
#import "Action.h"


@interface NetworkLocationAction : Action <ActionWithLimitedOptions> {
	NSString *networkLocation;
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
