//
//  NFCMirrorEvidenceSource.h
//  ControlPlane
//
//  Created by Eric Betts on 11/21/14.
//
//

#import "GenericEvidenceSource.h"
#import <IOKit/hid/IOHIDLib.h>
#import <IOKit/hid/IOHIDKeys.h>
#import <IOKit/hid/IOHIDManager.h>

#define UPSIDE_DOWN 5
#define RIGHTSIDE_UP 4
#define TAG_EVENT 2
#define MIRROR_REPORT_LENGTH 64
#define TAG_ON 1
#define TAG_OFF 2

@interface NFCMirrorEvidenceSource : GenericEvidenceSource {
    NSLock *lock;

    NSMutableArray *tags;
}

  @property IOHIDDeviceRef mirror;

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

- (NSArray *)getTags;


@end
