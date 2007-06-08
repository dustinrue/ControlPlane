//
//  IChatAction.h
//  MarcoPolo
//
//  Created by David Symonds on 8/06/07.
//

#import <Cocoa/Cocoa.h>
#import "Action.h"


@interface IChatAction : Action <ActionWithString> {
	NSString *status;
}

- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;

+ (NSString *)stringHelpText;
- (id)initWithString:(NSString *)string;

@end
