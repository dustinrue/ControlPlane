//
//  BluetoothScanRule.h
//  ControlPlane
//
//  Created by David Jennes on 16/10/11.
//  Copyright (c) 2011. All rights reserved.
//

#import <Plugins/Rules.h>

@interface BluetoothScannerRule : Rule<RuleProtocol> {
	NSString *m_address;
}

@end
