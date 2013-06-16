//
//  WiFiEvidenceSource2.h
//  ControlPlane
//
//  Created by Dustin Rue on 7/10/11.
//  Copyright 2011 Dustin Rue. All rights reserved.
//

#import "GenericLoopingEvidenceSource.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <Foundation/Foundation.h>


@class CWInterface, CWNetwork;
@interface WiFiEvidenceSourceCoreWLAN : GenericEvidenceSource  {
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
@property(strong) NSDictionary *interfaceData;
@property BOOL linkActive;
@property(strong) NSString *interfaceBSDName;
@property(strong) NSTimer *loopTimer;

// For SystemConfiguration asynchronous notifications
@property SCDynamicStoreRef store;
@property CFRunLoopSourceRef runLoop;

//@property(readwrite, retain) NSTimer *loopTimer;

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
- (void) getInterfaceStateInfo;

@end
