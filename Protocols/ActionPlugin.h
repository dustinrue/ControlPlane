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

@property (assign) CFDictionaryRef helperToolResponse;
@property (strong) NSString *type;
@property (strong) NSString *context;
@property (strong) NSString *when;
@property (strong) NSNumber *delay;
@property (strong) NSNumber *enabled;

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

/**
 *  A Toggleable action
 */
@protocol ToggleableAction <Action,ActionWithLimitedOptions>

@property (assign) BOOL turnOn;

- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;

+ (NSArray *)limitedOptions;
- (id)initWithOption:(NSNumber *)option;

@end

