//
//  SliderWithValue.h
//  MarcoPolo
//
//  Created by David Symonds on 15/07/07.
//

#import <Cocoa/Cocoa.h>


@interface ToolTipTextField : NSTextField {
}

@end

#pragma mark -

@interface ToolTip : NSObject {
	NSWindow *window;
	NSTextField *textField;
	NSDictionary *textAttributes;
}

@end

#pragma mark -

@interface SliderWithValue : NSSlider {
}

@end