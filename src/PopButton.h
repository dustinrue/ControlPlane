//
//  PopButton.h
//  ControlPlane
//
//  Created by David Symonds on 26/04/07.
//

#import <Cocoa/Cocoa.h>


@interface PopButton : NSButton {
	NSMenu *menu;
}

- (NSMenu *)menu;
- (void)setMenu:(NSMenu *)theMenu;

@end
