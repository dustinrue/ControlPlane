//
//  EvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 29/03/07.
//


@interface EvidenceSource : NSObject {
	BOOL running;
	BOOL dataCollected;
	BOOL startAfterSleep;
    BOOL goingToSleep;

	// Sheet hooks
	__unsafe_unretained NSPanel *panel;
	IBOutlet NSPopUpButton *ruleContext;
	IBOutlet NSSlider *ruleConfidenceSlider;
	NSString *oldDescription;
    NSMutableArray *rulesThatBelongToThisEvidenceSource;
    
    BOOL screenIsLocked;
}

@property (assign) IBOutlet NSButton *negateRule;
@property (readwrite) BOOL screenIsLocked;

+ (NSPanel *)getPanelFromNibNamed:(NSString *)name instantiatedWithOwner:(id)owner;

- (id)initWithPanel:(NSPanel *)initPanel;
- (id)initWithNibNamed:(NSString *)name;
- (void)dealloc;
- (void)goingToSleep:(id)arg;
- (void)wakeFromSleep:(id)arg;
- (void) screenSaverDidBecomeInActive:(NSNotification *) notification;
- (void) screenSaverDidBecomeActive:(NSNotification *) notification;
- (void) screenDidUnlock:(NSNotification *) notification;
- (void) screenDidLock:(NSNotification *) notification;
- (BOOL)matchesRulesOfType:(NSString *)type;

- (BOOL)dataCollected;
- (void)setDataCollected:(BOOL)collected;
- (BOOL)isRunning;

- (void)setThreadNameFromClassName;

- (void)setContextMenu:(NSMenu *)menu;
- (void)runPanelAsSheetOfWindow:(NSWindow *)window withParameter:(NSDictionary *)parameter
		 callbackObject:(NSObject *)callbackObject selector:(SEL)selector;
- (IBAction)closeSheetWithOK:(id)sender;
- (IBAction)closeSheetWithCancel:(id)sender;

// Need to be extended by descendant classes
// (need to add handling of 'parameter', and optionally 'type' and 'description' keys)
// Some rules:
//	- parameter *must* be filled in
//	- description *must not* be filled in if [super readFromPanel] does it
//	- type *may* be filled in; it will default to the first "supported" rule type
- (NSMutableDictionary *)readFromPanel;
- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type;

// To be implemented by descendant classes:
- (void)start;
- (void)stop;

// To be implemented by descendant classes:
- (NSString *)name;
- (BOOL)doesRuleMatch:(NSMutableDictionary *)rule;

// Optionally implemented by descendant classes
- (NSArray *)typesOfRulesMatched;	// optional; default is [self name]

// Returns the rules that belong to the calling evidence source
- (NSArray *)myRules;

// Returns a friendly name to be used in the drop down menu
- (NSString *) friendlyName;

// Return true if the evidence source should be enabled for this model of Mac
+ (BOOL) isEvidenceSourceApplicableToSystem;

@end

//////////////////////////////////////////////////////////////////////////////////////////

typedef NS_ENUM(int, RuleMatchStatusType) {
    RuleMatchStatusIsUnknown = -1,
    RuleDoesNotMatch = 0,
    RuleDoesMatch = 1
};

@interface EvidenceSourceSetController : NSObject {
	IBOutlet NSWindowController *prefsWindowController;
	NSArray *sources;	// dictionary of EvidenceSource descendants (key is its name)
}

- (EvidenceSource *)sourceWithName:(NSString *)name;
- (void)startEnabledEvidenceSources;
- (void)stopAllRunningEvidenceSources;
- (RuleMatchStatusType)ruleMatches:(NSMutableDictionary *)rule;
- (NSEnumerator *)sourceEnumerator;

@end
