//
//  FireWireRule.h
//  ControlPlane
//
//  Created by David Jennes on 29/09/11.
//  Copyright 2011. All rights reserved.
//

#import "Rule.h"

@interface FireWireRule : Rule<RuleProtocol> {
	NSNumber *m_guid;
}

@end
