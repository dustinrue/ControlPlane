//
//  WiFiEvidenceSource2.h
//  ControlPlane
//
//  Created by Dustin Rue on 7/10/11.
//  Copyright 2011 Dustin Rue. All rights reserved.
//
//  Bug fixes and improvements by Vladimir Beloborodov (VladimirTechMan) in Jul 2013.
//

#import "GenericEvidenceSource.h"
#import "CoreLocationSource.h"

@interface WiFiEvidenceSourceCoreWLAN : GenericEvidenceSource <CLLocationManagerDelegate>


@property BOOL currentNetworkIsSecure;

- (id)init;
- (void)dealloc;

- (void)clearCollectedData;

- (NSString *)name;
- (NSArray *)typesOfRulesMatched;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;
- (void) getInterfaceStateInfo;


@end
