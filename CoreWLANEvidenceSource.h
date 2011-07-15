//
//  WiFiEvidenceSource2.h
//  MarcoPolo
//
//  Created by Dustin Rue on 7/10/11.
//  Copyright 2011 Dustin Rue. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GenericLoopingEvidenceSource.h"

@class CWInterface, CWNetwork;
@interface WiFiEvidenceSourceCoreWLAN : GenericLoopingEvidenceSource  {
    NSLock *lock;
	NSMutableArray *apList;
	int wakeUpCounter;
    NSString *ssidString;
    NSString *signalStrength;
    NSString *macAddress;
    NSMutableArray *scanResults;
    CWInterface *currentInterface;
}

@property(readwrite, retain) CWInterface *currentInterface;
@property(readwrite, retain) NSMutableArray *scanResults;
@property(readwrite, retain) NSString *ssidString;
@property(readwrite, retain) NSString *signalStrength;
@property(readwrite, retain) NSString *macAddress;

- (id)init;
- (void)dealloc;

- (void)wakeFromSleep:(id)arg;

- (void)doUpdate;
- (void)clearCollectedData;
- (bool)isWirelessAvailable;

- (NSString *)name;
- (NSArray *)typesOfRulesMatched;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
