//
//  ToggleWiFiAction.h
//  MarcoPolo
//
//  Created by David Symonds on 3/04/07.
//

#import <Cocoa/Cocoa.h>
#import "ToggleableAction.h"


@interface ToggleWiFiAction : ToggleableAction <ActionWithLimitedOptions> {
}

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;

+ (NSArray *)limitedOptions;
+ (NSString *)limitedOptionHelpText;
- (id)initWithOption:(NSString *)option;

@end
