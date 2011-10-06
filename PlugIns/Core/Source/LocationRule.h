//
//  LocationRule.h
//  ControlPlane
//
//  Created by David Jennes on 25/09/11.
//  Copyright 2011. All rights reserved.
//

#import <Plugins/Rules.h>

@interface LocationRule : Rule<RuleProtocol> {
	CLLocation *m_location;
}

@end
