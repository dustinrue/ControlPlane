//
//  ActionPlugin.h
//  ControlPlane
//
//  Created by Dustin Rue on 8/10/12.
//
//

#import <Foundation/Foundation.h>

@class Action;

@protocol Action <NSObject>
/*{
	NSString *type, *context, *when;
	NSNumber *delay, *enabled;
    
    // terrible hack so that an action can
    // have response data from the helper tool
    // but because the helpertool is a category
    // action, it can't define its own ivars
    CFDictionaryRef helperToolResponse;
    
    NSAppleEventDescriptor *appleScriptResult_;
}
 */

@property (assign) CFDictionaryRef helperToolResponse;
@property (strong) NSString *type;
@property (strong) NSString *context;
@property (strong) NSString *when;
@property (strong) NSNumber *delay;
@property (strong) NSNumber *enabled;

+ (NSString *)typeForClass:(Class)klass;
+ (Class)classForType:(NSString *)type;

+ (Action *)actionFromDictionary:(NSDictionary *)dict;
- (id)init;
- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;
+ (NSString *)helpTextForActionOfType:(NSString *)type;

- (NSComparisonResult)compareDelay:(Action *)other;

// To be implemented by descendant classes:
- (NSString *)description;	// (use present-tense imperative)
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;
+ (NSString *)friendlyName;
+ (NSString *)menuCategory;

// Actions should override these if they need to wait until
// after the screen saver has quit, the screen has been unlocked
// or both.
+ (BOOL) shouldWaitForScreensaverExit;
+ (BOOL) shouldWaitForScreenUnlock;

// Helpers
- (BOOL)executeAppleScript:(NSString *)script;		// returns YES on success, NO on failure
- (NSArray *)executeAppleScriptReturningListOfStrings:(NSString *)script;

@end

@protocol ActionWithLimitedOptions <Action>
+ (NSArray *)limitedOptions;		// Returns an array of dictionaries (keys: option, description)
- (id)initWithOption:(NSObject *)option;
@end

@protocol ActionWithFileParameter <Action>
- (id)initWithFile:(NSString *)file;
@end

// An action whose creation UI should just prompt for a string (NSTextField)
@protocol ActionWithString <Action>
@end

