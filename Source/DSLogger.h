//
//  DSLogger.h
//  ControlPlane
//
//  Created by David Symonds on 22/07/07.
//  Modified by Vladimir Beloborodov on 01 Apr 2013.
//


@interface DSLogger : NSObject

+ (void)initialize;

+ (DSLogger *)sharedLogger;
+ (void)logFromFunction:(NSString *)fnName withInfo:(NSString *)info;

- (id)init;
- (void)dealloc;

- (void)logFromFunction:(NSString *)fnName withInfo:(NSString *)info;
- (NSString *)buffer;

#define DSLog(format, ...)	\
	[DSLogger logFromFunction:[NSString stringWithUTF8String:__PRETTY_FUNCTION__] withInfo:[NSString stringWithFormat:(format),##__VA_ARGS__]]

@end
