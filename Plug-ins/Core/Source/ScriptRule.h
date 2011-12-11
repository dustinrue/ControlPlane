//
//  ScriptRule.h
//  ControlPlane
//
//  Created by David Jennes on 10/12/11.
//  Copyright 2011. All rights reserved.
//

#import <Plugins/Rules.h>

@interface ScriptRule : Rule<RuleProtocol> {
	double m_delay;
	NSArray *m_script;
	NSNumber *m_result;
}

@property (readonly) double delay;
@property (readonly) NSArray *script;

@end
