//
//  ToggleBluetoothAction.h
//  MarcoPolo
//
//  Created by David Symonds on 3/04/07.
//

#import <Cocoa/Cocoa.h>
#import "ToggleableAction.h"


@interface ToggleBluetoothAction : ToggleableAction <ActionWithLimitedOptions> {
	int setState;
}

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;

+ (NSArray *)limitedOptions;
+ (NSString *)limitedOptionHelpText;
- (id)initWithOption:(NSString *)option;

@end
