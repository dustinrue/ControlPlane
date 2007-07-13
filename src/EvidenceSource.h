//
//  EvidenceSource.h
//  MarcoPolo
//
//  Created by David Symonds on 29/03/07.
//

#import <Cocoa/Cocoa.h>


@interface EvidenceSource : NSObject {
	BOOL running;
	BOOL dataCollected;
	BOOL startAfterSleep;
}

- (id)init;
- (void)dealloc;
- (void)goingToSleep:(id)arg;
- (void)wakeFromSleep:(id)arg;
- (BOOL)matchesRulesOfType:(NSString *)type;

- (BOOL)dataCollected;
- (void)setDataCollected:(BOOL)collected;
- (BOOL)isRunning;

// To be implemented by descendant classes:
- (void)start;
- (void)stop;

// To be implemented by descendant classes:
// TODO: some of these could be class methods
- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSArray *)getSuggestions;	// NSArray of NSDictionary: keys are type, parameter, description

// Optionally implemented by descendant classes
- (NSArray *)typesOfRulesMatched;	// optional; default is [self name]
- (NSString *)getSuggestionLeadText:(NSString *)type;	// optional; default is "The presence of"

@end

// A few evidence sources just need to continuously loop
@interface LoopingEvidenceSource : EvidenceSource {
	NSTimeInterval loopInterval;
	NSTimer *loopTimer;
}

- (id)init;	// can be overridden by descendant classes to change loopInterval
- (void)dealloc;

- (void)start;
- (void)stop;

// should be implemented by descendant classes
//- (void)doUpdate;
//- (void)clearCollectedData;

@end

//////////////////////////////////////////////////////////////////////////////////////////

@interface EvidenceSourceSetController : NSObject {
	IBOutlet NSWindowController *prefsWindowController;
	NSArray *sources;	// dictionary of EvidenceSource descendants (key is its name)
	NSArray *ruleTypes;
}

- (EvidenceSource *)sourceWithName:(NSString *)name;
- (void)startOrStopAll;
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