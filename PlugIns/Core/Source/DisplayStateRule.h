//
//	DisplayStateRule.h
//	ControlPlane
//
//	Created by David Jennes on 30/09/11.
//	Copyright 2011. All rights reserved.
//

#import <Plugins/Rules.h>

@interface DisplayStateRule : Rule<RuleProtocol> {
	NSUInteger m_state;
}

@end
