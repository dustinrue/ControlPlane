//
//  NetworkLinkRule.h
//  ControlPlane
//
//  Created by David Jennes on 04/10/11.
//  Copyright 2011. All rights reserved.
//

#import "Rule.h"

@interface NetworkLinkRule : Rule {
	NSString *m_name;
	BOOL m_active;
}

@end
