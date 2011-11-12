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
static classname *accessorMethodName = nil; \
 \
+ (classname *) accessorMethodName { \
	static dispatch_once_t once; \
	 \
    dispatch_once(&once, ^{ \
		accessorMethodName = [classname alloc]; \
		accessorMethodName = [accessorMethodName init]; \
	}); \
	 \
    return accessorMethodName; \
}

#define SYNTHESIZE_SINGLETON_FOR_CLASS(classname) SYNTHESIZE_SINGLETON_FOR_CLASS_WITH_ACCESSOR(classname, shared##classname)
