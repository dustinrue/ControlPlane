//
//  SliderWithValue.h
//  ControlPlane
//
//  Created by David Symonds on 15/07/07.
//


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

@interface SliderCellWithValue : NSSliderCell {
}

+ (NSString *)toolTipTextForValue:(double)value;

@end

#pragma mark -

@interface SliderWithValue : NSSlider {
}

@end
