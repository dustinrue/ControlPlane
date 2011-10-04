//
//	USBRule.h
//	ControlPlane
//
//	Created by David Jennes on 30/09/11.
//	Copyright 2011. All rights reserved.
//

#import "Rule.h"

@interface USBRule : Rule<RuleProtocol> {
	NSNumber *m_product;
	NSNumber *m_vendor;
}

@end
