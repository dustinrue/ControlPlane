//
//  Action.h
//  ControlPlane
//
//  Created by David Symonds on 3/04/07.
//


#import "BetterAuthorizationSampleLib.h"
#import "CPHelperToolCommon.h"

static AuthorizationRef gAuth;

@interface Action : NSObject {
	NSString *type, *context, *when;
	NSNumber *delay, *enabled;
    OSStatus        error; 
    BASFailCode     failCode;
    NSString *      bundleID;
    NSDictionary *  request;
    CFDictionaryRef response;

}

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

@end

@protocol ActionWithLimitedOptions
+ (NSArray *)limitedOptions;		// Returns an array of dictionaries (keys: option, description)
- (id)initWithOption:(NSObject *)option;
@end

@protocol ActionWithFileParameter
- (id)initWithFile:(NSString *)file;
@end

// An action whose creation UI should just prompt for a string (NSTextField)
@protocol ActionWithString
@end

//////////////////////////////////////////////////////////////////////////////////////////

@interface ActionSetController : NSObject {
	IBOutlet NSWindowController *prefsWindowController;
	NSArray *classes;	// array of class objects
}

- (NSArray *)types;

// NSMenu delegates
- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(int)index shouldCancel:(BOOL)shouldCancel;
- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action;
- (NSUInteger)numberOfItemsInMenu:(NSMenu *)menu;


@end
