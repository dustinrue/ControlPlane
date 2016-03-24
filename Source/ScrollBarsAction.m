//
//  ScrollBarsAction.m
//  ControlPlane
//
//  Created by Brandon LeBlanc on 3/24/16.
//
//

#import "ScrollBarsAction.h"

@interface ScrollBarsAction ()

@property(copy) NSString *setting;

@end

@implementation ScrollBarsAction

- (instancetype)initWithOption:(NSString *)option {
  self = [super init];
  if (self) {
    self.setting = option;
  }

  return self;
}

- (instancetype)init {
  return [self initWithOption:@""];
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
  return [self initWithOption:dict[@"parameter"]];
}

- (void)dealloc {
  self.setting = nil;
  [super dealloc];
}

- (NSMutableDictionary *)dictionary {
  NSMutableDictionary *dict = [super dictionary];
  dict[@"parameter"] = self.setting;
  return dict;
}

- (NSString *)description {
  NSString *format = NSLocalizedString(@"Show Scroll Bars: %@", @"");
  return [NSString stringWithFormat:format, self.setting];
}

- (BOOL)execute:(NSString **)errorString {
  CFPreferencesSetValue(CFSTR("AppleShowScrollBars"), (CFStringRef)self.setting,
			kCFPreferencesAnyApplication, kCFPreferencesCurrentUser,
			kCFPreferencesAnyHost);

  CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser,
			   kCFPreferencesAnyHost);

  [[NSDistributedNotificationCenter defaultCenter]
   postNotificationName:@"AppleShowScrollBarsSettingChanged"
   object:NULL];

  return YES;
}

+ (NSString *)helpText {
  return NSLocalizedString(@"Show scroll bars setting correlates to the option in"
			   @" System Preferences.app.",
			   @"");
}

+ (NSString *)creationHelpText {
  return NSLocalizedString(@"Show Scroll Bars", @"");
}

+ (NSArray *)limitedOptions {
  return @[
	   @{ @"option" : @"Always",
	      @"description" : NSLocalizedString(@"Always", @"") },
	   @{
	     @"option" : @"WhenScrolling",
	     @"description" : NSLocalizedString(@"When scrolling", @"")
	     },
	   @{
	     @"option" : @"Automatic",
	     @"description" :
	       NSLocalizedString(@"Automatically based on mouse or trackpad", @"")
	     },
	   ];
}

+ (NSString *)friendlyName {
  return NSLocalizedString(@"Show Scroll Bars", @"");
}

+ (NSString *)menuCategory {
  return NSLocalizedString(@"System Preferences", @"");
}

@end
