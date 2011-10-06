//
//  KeyboardBrightnessRule.h
//  ControlPlane
//
//  Created by David Jennes on 30/09/11.
//  Copyright 2011. All rights reserved.
//

#import <Plugins/Rules.h>

@interface KeyboardBrightnessRule : Rule<RuleProtocol> {
	double m_treshold;
	BOOL m_above;
}

@end
