//
//  EvidenceSourcePlugin.h
//  ControlPlane
//
//  Created by Dustin Rue on 8/2/12.
//
//

#import <Foundation/Foundation.h>

@protocol EvidenceSourcePlugin <NSObject>


/*!
 * @method
 * @abstract read data from the panel
 * @discussion
 *   Need to be extended by descendant classes
 *   (need to add handling of 'parameter', and optionally 'type' and 'description' keys)
 *   Some rules:
 *      - parameter *must* be filled in
 *      - description *must not* be filled in if [super readFromPanel] does it
 *      - type *may* be filled in; it will default to the first "supported" rule type
 * @result dictionary containing values on the panel
 */
- (NSMutableDictionary *)readFromPanel;

/*!
 * @method
 * @abstract write data to the panel
 */
- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type;

/*! @methodgroup Start/Stop control */
/*!
 * @method
 * @abstract Start an evidence source
 */
- (void)start;

/*!
 * @method
 * @abstract Stop an evidence source
 */
- (void)stop;


/*!
 * @method
 * @abstract 
 */
- (NSString *)name;

/*!
 * @method
 * @abstract does the given rule match?
 * @param rule The rule to test
 * @result <i>YES</i> if the rule matches
 */
- (BOOL)doesRuleMatch:(NSDictionary *)rule;


/*!
 * @method
 * @abstract returns the rules that this plugin matches from the stored config data
 * @result an array of the rules that belong to this plugin
 */
- (NSArray *)myRules;

/*!
 * @method
 * @abstract dealloc method would only be needed if you're not compiling with ARC
 */
- (void)dealloc NS_AUTOMATED_REFCOUNT_UNAVAILABLE;


/*!
 * @method
 * @abstract Returns a friendly name to be used in the drop down menu during config time
 * @result string value to be displayed to the user when enabling, disabling the evidence source
 *   or when creating a rule for the evidence source
 */
- (NSString *) friendlyName;

@optional

/*!
 * @property
 * @abstract is the screen locked or not.
 * @discussion useful for if you want to delay rule checking while the screen is locked
 */
@property (readwrite) BOOL screenIsLocked;

/*!
 * @method
 * @abstract type of rule this plugin matches if different from its name or if it matches multiple rules
 * @result NSArray of the types of rules this plugin matches
 */
- (NSArray *)typesOfRulesMatched;	// optional; default is [self name]

/*!
 * @method
 * @abstract called if the system is going to sleep
 */
- (void)goingToSleep:(id)arg;

/*!
 * @method
 * @abstract called if the system is waking from sleep
 */
- (void)wakeFromSleep:(id)arg;

/*!
 * @
- (void) screenSaverDidBecomeInActive:(NSNotification *) notification;
- (void) screenSaverDidBecomeActive:(NSNotification *) notification;
- (void) screenDidUnlock:(NSNotification *) notification;
- (void) screenDidLock:(NSNotification *) notification;
 */

@end

/*
@interface EvidenceSource : NSObject {
	BOOL running;
	BOOL dataCollected;
	BOOL startAfterSleep;
    BOOL goingToSleep;
    
	// Sheet hooks
	NSPanel *panel;
	IBOutlet NSPopUpButton *ruleContext;
	IBOutlet NSSlider *ruleConfidenceSlider;
	NSString *oldDescription;
    NSMutableArray *rulesThatBelongToThisEvidenceSource;
    
    BOOL screenIsLocked;
}

@property (readwrite) BOOL screenIsLocked;

- (id)initWithNibNamed:(NSString *)name;



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



@end
*/