//
//  AboutPanel.h
//  MarcoPolo
//
//  Created by David Symonds on 2/08/07.
//

#import <Cocoa/Cocoa.h>


@interface AboutPanel : NSObject {
	NSPanel *panel;
}

- (id)init;
- (void)dealloc;

- (void)runPanel;

- (NSString *)versionString;

@end
