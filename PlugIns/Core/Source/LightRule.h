//
//  LightRule.h
//  ControlPlane
//
//  Created by David Jennes on 30/09/11.
//  Copyright 2011. All rights reserved.
//

#import "Rule.h"

@interface LightRule : Rule<RuleProtocol> {
	double m_treshold;
	BOOL m_above;
}

@end
