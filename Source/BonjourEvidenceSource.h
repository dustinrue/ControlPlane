//
//  BonjourEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 27/08/07.
//

#import "GenericEvidenceSource.h"
#import "CPBonjourResolver.h"


@interface BonjourEvidenceSource : GenericEvidenceSource<CPBonjourResolverDelegate> {
	NSLock *lock;

	// TODO: do we need an NSLock to protect this stuff?
	int stage;	// 0 = idle, 1 = searching for services, 2 = enumerating those services
    
    // this is the top level browser responsible for storing the
    // all found services in the local domain
	CPBonjourResolver *topLevelNetworkBrowser;
    
    // for each type of service that the top level browser
    // finds we create a new NSNetService object responsible
    // for figuring out what hosts actually offer that service
    NSMutableArray *cpBonjourResolvers;
    
    // For each service on a host in cpBonjourResolvers
    // 
    NSMutableArray *servicesBeingResolved;
    
    // full resolved services, we now know what service
    // and what host
	NSMutableArray *services;
    
    
	NSTimer *scanTimer;

	NSMutableArray *hits;
	NSMutableArray *hitsInProgress;
}

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
