//
//  BonjourEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 27/08/07.
//

#import "GenericEvidenceSource.h"
#import "CPBonjourResolver.h"


@interface BonjourEvidenceSource : GenericEvidenceSource<CPBonjourResolverDelegate> 

@property (strong) NSLock *lock;

// TODO: do we need an NSLock to protect this stuff?
@property (assign) int stage;	// 0 = idle, 1 = searching for services, 2 = enumerating those services

// this is the top level browser responsible for storing the
// all found services in the local domain
@property (strong) CPBonjourResolver *topLevelNetworkBrowser;

// For each service on a host in cpBonjourResolvers
//
@property (strong) NSMutableArray *servicesBeingResolved;

// for each type of service that the top level browser
// finds we create a new NSNetService object responsible
// for figuring out what hosts actually offer that service
@property (strong) NSMutableArray *cpBonjourResolvers;

// full resolved services, we now know what service
// and what host
@property (strong) NSMutableArray *services;

// service level browsers by their type
@property (strong) NSMutableDictionary *servicesByType;


@property (strong) NSTimer *scanTimer;

@property (strong) NSMutableArray *hits;
@property (strong) NSMutableArray *hitsInProgress;


- (id)init;
- (void)dealloc;

- (void)start;
- (void)stop;

- (void)clearCollectedData;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
