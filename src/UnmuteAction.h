//
//  UnmuteAction.h
//  MarcoPolo
//
//  Created by David Symonds on 7/06/07.
//

#import <Cocoa/Cocoa.h>
#import "Action.h"


@interface UnmuteAction : Action {
}

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;

@end
