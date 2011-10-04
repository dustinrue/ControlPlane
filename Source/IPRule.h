//
//  IPRule.h
//  ControlPlane
//
//  Created by David Jennes on 04/10/11.
//  Copyright 2011. All rights reserved.
//

#import "Rule.h"

typedef union {
	char octets[4];
	int32_t value;
} Address;

@interface IPRule : Rule {
	Address m_ip;
	Address m_mask;
}

@end
