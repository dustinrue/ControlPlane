//
//  ToggleBluetoothAction.h
//  ControlPlane
//
//  Created by David Symonds on 3/04/07.
//

#import "ToggleableAction.h"


@interface ToggleBluetoothAction : ToggleableAction {
	int setState;
}

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

@end
