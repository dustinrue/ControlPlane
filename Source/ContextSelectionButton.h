//
//  ContextSelectionButton.h
//  ControlPlane
//
//  Created by David Symonds on 6/07/07.
//

#import "ContextsDataSource.h"


@interface ContextSelectionButton : NSPopUpButton {
	ContextsDataSource *contextsDataSource;
}

- (void)setContextsDataSource:(ContextsDataSource *)dataSource;

@end
