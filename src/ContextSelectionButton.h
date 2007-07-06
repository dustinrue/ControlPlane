//
//  ContextSelectionButton.h
//  MarcoPolo
//
//  Created by David Symonds on 6/07/07.
//

#import <Cocoa/Cocoa.h>
#import "ContextsDataSource.h"

@interface ContextSelectionButton : NSPopUpButton {
	ContextsDataSource *contextsDataSource;
//	NSString *selectedObject;
}

- (void)setContextsDataSource:(ContextsDataSource *)dataSource;

@end
