//
//  EvidenceSource.h
//  MarcoPolo
//
//  Created by David Symonds on 29/03/07.
//

#import <Cocoa/Cocoa.h>

typedef enum {
	ES_NOT_STARTED = 0,
	ES_STARTING,
	ES_IDLE,
	ES_UPDATING,	// Either an update is required, or it's time to die
	ES_FINISHED,
	ES_SLEEPING
} EvidenceSourceState;

@interface EvidenceSource : NSObject {
	NSThread *thread;

	NSConditionLock *threadCond;
	BOOL timeToDie;
	int wakeUpCounter;
	BOOL sourceEnabled, dataCollected;
	NSTimer *updateTimer;

	NSAutoreleasePool *threadPool;
	NSTimeInterval updateInterval;
	NSString *defaultsEnabledKey;
}

- (id)init;
- (void)dealloc;
- (void)startThread;
- (void)blockOnThread;	// Should be called by descendant -dealloc methods first!
- (void)goingToSleep:(id)arg;
- (void)wakeFromSleep:(id)arg;
- (BOOL)matchesRulesOfType:(NSString *)type;

- (BOOL)dataCollected;
- (void)setDataCollected:(BOOL)collected;

// To be implemented by descendant classes:
// TODO: some of these could be class methods
- (void)doUpdate;
- (NSString *)name;
- (NSArray *)typesOfRulesMatched;	// optional; default is [self name]
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;	// optional; default is "The presence of"
- (NSArray *)getSuggestions;	// NSArray of NSDictionary: keys are type, parameter, description

@end

//////////////////////////////////////////////////////////////////////////////////////////

@interface EvidenceSourceSetController : NSObject {
	IBOutlet NSWindowController *prefsWindowController;
	NSArray *sources;	// dictionary of EvidenceSource descendants (key is its name)
	NSArray *ruleTypes;
}

- (EvidenceSource *)sourceWithName:(NSString *)name;
- (void)startAll;
- (BOOL)ruleMatches:(NSDictionary *)rule;
- (NSArray *)getSuggestionsFromSource:(NSString *)name ofType:(NSString *)type;		// type may be nil
- (NSEnumerator *)sourceEnumerator;

// NSMenu delegates (for adding rules)
- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(int)index shouldCancel:(BOOL)shouldCancel;
- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action;
- (int)numberOfItemsInMenu:(NSMenu *)menu;

// NSTableViewDataSource protocol methods
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;

@end