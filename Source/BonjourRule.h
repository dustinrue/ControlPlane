//
//	BonjourRule.h
//	ControlPlane
//
//	Created by David Jennes on 24/09/11.
//	Copyright 2011. All rights reserved.
//

#import "Rule.h"

@interface BonjourRule : Rule<RuleProtocol> {
	NSString *m_host;
	NSString *m_service;
}

@end
