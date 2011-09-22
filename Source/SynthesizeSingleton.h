//
//	AudioOutputSource.m
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Based on SynthesizeSingleton from CocoaWithLove.
//	Copyright 2011. All rights reserved.
//

#define SYNTHESIZE_SINGLETON_FOR_CLASS_WITH_ACCESSOR(classname, accessorMethodName) \
 \
static void * volatile accessorMethodName = nil; \
 \
+ (classname *) accessorMethodName { \
	while (!accessorMethodName) { \
		classname *temp = [[self alloc] init]; \
		 \
		if (!OSAtomicCompareAndSwapPtrBarrier(0x0, temp, &accessorMethodName)) \
			[temp release]; \
	} \
	 \
	return accessorMethodName; \
} \
\
- (id) retain { \
	return accessorMethodName; \
} \
\
- (NSUInteger) retainCount { \
	return NSUIntegerMax; \
} \
 \
- (oneway void) release { \
} \
 \
- (id) autorelease { \
    return accessorMethodName; \
}

#define SYNTHESIZE_SINGLETON_FOR_CLASS(classname) SYNTHESIZE_SINGLETON_FOR_CLASS_WITH_ACCESSOR(classname, shared##classname)
