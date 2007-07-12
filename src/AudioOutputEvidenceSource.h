//
//  AudioOutputEvidenceSource.h
//  MarcoPolo
//
//  Created by David Symonds on 11/07/07.
//

#import <Cocoa/Cocoa.h>
#import <CoreAudio/CoreAudio.h>
#import "EvidenceSource.h"


@interface AudioOutputEvidenceSource : EvidenceSource {
	AudioDeviceID deviceID;
	NSString *source;
}

- (id)init;
- (void)dealloc;

- (void)doRealUpdate;

- (void)start;
- (void)stop;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
