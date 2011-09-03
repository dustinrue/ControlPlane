//
//  BonjourEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 27/08/07.
//

#import "GenericLoopingEvidenceSource.h"


@interface BonjourEvidenceSource : GenericLoopingEvidenceSource<NSNetServiceBrowserDelegate> {
	NSLock *lock;

	// TODO: do we need an NSLock to protect this stuff?
	int stage;	// 0 = idle, 1 = searching for services, 2 = enumerating those services
	NSNetServiceBrowser *browser;
	NSMutableArray *services;
	NSTimer *scanTimer;

	NSMutableArray *hits;
	NSMutableArray *hitsInProgress;
}

- (id)init;
- (void)dealloc;

- (void)start;
- (void)stop;

- (void)doUpdate;
- (void)clearCollectedData;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
