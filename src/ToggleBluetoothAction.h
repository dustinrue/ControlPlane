//
//  ToggleBluetoothAction.h
//  MarcoPolo
//
//  Created by David Symonds on 3/04/07.
//

#import <Cocoa/Cocoa.h>
#import "Action.h"


@interface ToggleBluetoothAction : Action <ActionWithLimitedOptions> {
	BOOL turnOn;
	int setState;
}

- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;

+ (NSArray *)limitedOptions;
+ (NSString *)limitedOptionHelpText;
- (id)initWithOption:(NSString *)option;

@end
