/*
 * KVOAdditions.m
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <devin at shiftedbits dot org> (Devin Lane) wrote this file. 
 * As long as you retain this notice you can do whatever you want with this
 * stuff. If we meet some day, and you think this stuff is worth it, you can
 * buy me a beer in return.
 *
 * Version 1.2.2:
 *		- Fixed crash due to missing __KVOAdditions__dealloc__original__
 *			method on NSObject.
 *
 * Version 1.2.1:
 *		- Now runs on iPhone OS 2.0
 *
 * Version 1.2: 
 *		- Added automatic -KVODealloc invocation
 *		- The selector is now considered in the uniqueness of an observation
 *		- New removeObserver:forKeyPath:selector: method
 * 
 * Version 1.1: Two critical bug fixes.
 *		- Multiple observers for the same key path are now handled correctly. 
 *		- Subclasses that override removeObserver:forKeyPath: are no longer
 *			swizzled incorrectly.
 * Version 1.0: Initial release
 */

#import "KVOAdditions.h"
#import <pthread.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <Availability.h>

/* Because NSMapTable not available on iPhone OS 2.0, and we want to use it 
 * on Mac OS X to take advantage of zeroed weak memory under GC, we make a
 * set of map table functions that use NSMapTable on Mac OS X, and CFDictionary
 * on iPhone OS. */

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_2_0

#define MapTableWithWeakToStrong() \
	(CFMutableDictionaryRef)[(id)CFDictionaryCreateMutable(kCFAllocatorDefault, \
		0, NULL, &kCFTypeDictionaryValueCallBacks) autorelease]

#define MapTableWithStrongCopyInToStrong() \
	(CFMutableDictionaryRef)[(id)CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFCopyStringDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks) autorelease]

#define MapTableWithOpaqueToStrong() MapTableWithWeakToStrong()

#define MapTableGet(table, key) \
	(void *)CFDictionaryGetValue(table, key)

#define MapTableInsert(table, key, value) \
	CFDictionarySetValue(table, (const void *)key, (const void *)value)

#define MapTableRemove(table, key) \
	CFDictionaryRemoveValue(table, (const void *)key)

#define MapTableGetCount(table) \
	CFDictionaryGetCount(table)

#define EnumerateMapTable(table) \
	NSUInteger table##count__ = CFDictionaryGetCount(table); \
	const void **table##keys__ = calloc(1, sizeof(void *) * table##count__); \
	const void **table##values__ = calloc(1, sizeof(void *) * table##count__); \
	CFDictionaryGetKeysAndValues(table, table##keys__, table##values__); \
	NSUInteger table##i__ = 0 \

#define NextMapEnumeratorPair(table, keyPtr, valuePtr) \
	((table##i__ < table##count__) && ((*(keyPtr) = ((void **)table##keys__)[table##i__], \
		*(valuePtr) = ((void **)table##values__)[table##i__]), ++table##i__))

#define EndMapTableEnumeration(table) \
	free((void *)table##keys__); \
	free((void *)table##values__)

#define MapTable CFMutableDictionaryRef

#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)

#define MapTableWithWeakToStrong() \
	[[[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsObjectPersonality | NSPointerFunctionsZeroingWeakMemory \
							   valueOptions:NSPointerFunctionsObjectPersonality | NSPointerFunctionsStrongMemory  \
					 			   capacity:0] autorelease]

#define MapTableWithStrongCopyInToStrong() \
	[[[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsObjectPersonality | NSPointerFunctionsStrongMemory | NSPointerFunctionsCopyIn \
							   valueOptions:NSPointerFunctionsObjectPersonality | NSPointerFunctionsStrongMemory  \
								   capacity:0] autorelease]

#define MapTableWithOpaqueToStrong() \
	[[[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsOpaquePersonality | NSPointerFunctionsOpaqueMemory \
							   valueOptions:NSPointerFunctionsObjectPersonality | NSPointerFunctionsStrongMemory \
								   capacity:0] autorelease]

#define MapTableGet(table, key) \
	[table objectForKey:(id)key]

#define MapTableInsert(table, key, value) \
	[table setObject:(id)value forKey:(id)key]

#define MapTableRemove(table, key) \
	[table removeObjectForKey:(id)key]

#define MapTableGetCount(table) \
	[table count]

#define EnumerateMapTable(table) \
	NSMapEnumerator table##enu__ = NSEnumerateMapTable(table) \

#define NextMapEnumeratorPair(table, keyPtr, valuePtr) \
	NSNextMapEnumeratorPair(&table##enu__, (void **)(keyPtr), (void **)(valuePtr))

#define EndMapTableEnumeration(table) \
	NSEndMapTableEnumeration(&table##enu__)

#define MapTable NSMapTable*

#else
#error Platform should be either Mac OS X or iPhone OS
#endif

static __strong MapTable receiverToKeyPathToObserverToSelectorToSurrogate = nil;
static pthread_once_t once = PTHREAD_ONCE_INIT;
static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

/* The surrogate object is used as the actual observer. When it receives 
 * -[NSObject observeValueForKeyPath:ofObject:change:context:], it fires `selector'
 * on `target'. */

@interface Surrogate : NSObject {
	__weak id target;
	__weak SEL selector;
	NSKeyValueObservingOptions options;
}

@property(assign) SEL selector;

- (id)initWithTarget:(id)aTarget
			selector:(SEL)aSelector
			 options:(NSKeyValueObservingOptions)theOptions;

@end

@implementation Surrogate
- (id)initWithTarget:(id)aTarget 
			selector:(SEL)aSelector 
			 options:(NSKeyValueObservingOptions)theOptions
{
	if ((self = [super init])) {
		/* None of these are retained */
		target = aTarget;
		selector = aSelector;
		options = theOptions;
	}
	
	return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object 
						change:(NSDictionary *)change
					   context:(void *)context
{
	if (!target || !selector) return;
	
	NSMethodSignature *sig = [target methodSignatureForSelector:selector];
	if (!sig) return;
	
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
	if (!invocation) return;
	
	/* Receiving methods can have the following signatures:
	 * - (void)valueDidChange;
	 * - (void)valueDidChange:(NSDictionary *)change;
	 *
	 * In addition, if NSKeyValueObservingOptionOld or NSKeyValueObservingOptionNew
	 * is included in options, the following can be used:
	 *
	 * - (void)valueDidChange:(id)oldValue newValue:(id)newValue
	 * - (void)valueDidChange:(id)oldValue newValue:(id)newValue isPrior:(BOOL)prior
	 */
	
	id old, new;
	BOOL prior;
	if ([sig numberOfArguments] == 3) {
		[invocation setArgument:&change atIndex:2];
	} else if ((options & NSKeyValueObservingOptionOld) ||
			   (options & NSKeyValueObservingOptionNew)) {
		if ([sig numberOfArguments] >= 4) {
			old = [change objectForKey:NSKeyValueChangeOldKey];
			new = [change objectForKey:NSKeyValueChangeNewKey];
			[invocation setArgument:&old atIndex:2];
			[invocation setArgument:&new atIndex:3];
		}
		if ([sig numberOfArguments] >= 5) {
			prior = [[change objectForKey:NSKeyValueChangeNotificationIsPriorKey] boolValue];
			[invocation setArgument:&prior atIndex:4];
		}
	}
	
	[invocation setSelector:selector];
	[invocation invokeWithTarget:target];
}

@synthesize selector;
@end



@interface NSObject (KVOAdditionsPrivate)
- (void)__KVOAdditions__dealloc__;
- (void)__KVOAdditions__dealloc__original__;
+ (CFMutableSetRef)__deallocClasses;
@end

static void initialize(void)
{
	receiverToKeyPathToObserverToSelectorToSurrogate = MapTableWithWeakToStrong();
	[(id)receiverToKeyPathToObserverToSelectorToSurrogate retain];
}

/* Adds `observer' to `receiver' for `keyPath', with options `options'. When a property change
 * occurs, `selector' is fired. The observer is recorded such that it can be found by
 * receiver.keyPath.observer.selector. This is required to allow a class to observe a property on a single
 * object and receive notification messages on different selectors, such as to support superclass observation. */

static void AddObserver(NSObject *receiver, NSObject *surrogate,
	NSObject *observer, SEL selector, NSString *keyPath, NSKeyValueObservingOptions options)
{
	pthread_once(&once, &initialize);
	pthread_mutex_lock(&mutex);
	
	MapTable keyPathToObserverToSelectorToSurrogate = 
		MapTableGet(receiverToKeyPathToObserverToSelectorToSurrogate, receiver);
	if (!keyPathToObserverToSelectorToSurrogate) {
		keyPathToObserverToSelectorToSurrogate = MapTableWithStrongCopyInToStrong();
		MapTableInsert(receiverToKeyPathToObserverToSelectorToSurrogate, receiver, keyPathToObserverToSelectorToSurrogate);
	}
	
	MapTable observerToSelectorToSurrogate = MapTableGet(keyPathToObserverToSelectorToSurrogate, keyPath);
	if (!observerToSelectorToSurrogate) {
		/* The observer is not retained */
		observerToSelectorToSurrogate = MapTableWithWeakToStrong();
		MapTableInsert(keyPathToObserverToSelectorToSurrogate, keyPath, observerToSelectorToSurrogate);
	}
	
	MapTable selectorToSurrogate = MapTableGet(observerToSelectorToSurrogate, observer);
	if (!selectorToSurrogate) {
		selectorToSurrogate = MapTableWithOpaqueToStrong();
		MapTableInsert(observerToSelectorToSurrogate, observer, selectorToSurrogate);
	}
		
	Surrogate *existingSurrogate = MapTableGet(selectorToSurrogate, selector);
	if (existingSurrogate) {
		/* Just call the new selector when the observation is triggered */
		existingSurrogate.selector = selector;
	} else {
		MapTableInsert(selectorToSurrogate, selector, surrogate);
		[receiver addObserver:surrogate forKeyPath:keyPath options:options context:NULL];
	}
	
	pthread_mutex_unlock(&mutex);
}

static BOOL RemoveSelfObservations(NSObject *object)
{
	pthread_once(&once, &initialize);
	pthread_mutex_lock(&mutex);
	
	BOOL removed = NO;
	
	do {
		MapTable keyPathToObserverToSelectorToSurrogate = 
			MapTableGet(receiverToKeyPathToObserverToSelectorToSurrogate, object);
		if (!keyPathToObserverToSelectorToSurrogate) break;
		
		NSMutableArray *expiredMapTableKeys = [NSMutableArray array];
		
		EnumerateMapTable(keyPathToObserverToSelectorToSurrogate);
		MapTable observerToSelectorToSurrogate;
		NSString *keyPath;
		while (NextMapEnumeratorPair(keyPathToObserverToSelectorToSurrogate, 
				&keyPath, &observerToSelectorToSurrogate)) {
			MapTable selectorToSurrogate = MapTableGet(observerToSelectorToSurrogate, object);
			if (!selectorToSurrogate) continue;
			
			/* Remove every observed selector */
			EnumerateMapTable(selectorToSurrogate);
			SEL aSelector;
			Surrogate *aSurrogate;
			while (NextMapEnumeratorPair(selectorToSurrogate, &aSelector, &aSurrogate)) {
				[object removeObserver:aSurrogate forKeyPath:keyPath];
			}
			EndMapTableEnumeration(selectorToSurrogate);
			
			/* Remove all selectors */
			MapTableRemove(observerToSelectorToSurrogate, object);
			
			/* We can't remove these while enumerating, so we mark
			 * them and remove them later */
			if (!MapTableGetCount(observerToSelectorToSurrogate)) {
				[expiredMapTableKeys addObject:keyPath];
			}
		}
		EndMapTableEnumeration(keyPathToObserverToSelectorToSurrogate);
		
		for (keyPath in expiredMapTableKeys) {
			MapTableRemove(keyPathToObserverToSelectorToSurrogate, keyPath);
		}
		
		if (!MapTableGetCount(keyPathToObserverToSelectorToSurrogate)) {
			MapTableRemove(receiverToKeyPathToObserverToSelectorToSurrogate, object);
		}
		
		removed = YES;
	} while (0);
	
	pthread_mutex_unlock(&mutex);
	
	return removed;
}

/* Removes `observer' observing `keyPath' on `receiver', notified by selector `selector'. 
 * The surrogate observer object is removed and released. Returns YES if an
 * observer was removed. A `selector' value of NULL will remove all selectors on `observer.' */

static BOOL RemoveObserver(NSObject *receiver, NSString *keyPath, 
	NSObject *observer, SEL selector)
{
	if (receiver == nil || observer == nil || keyPath == nil) return NO;
	
	pthread_once(&once, &initialize);
	pthread_mutex_lock(&mutex);
	
	BOOL removed = NO;
	
	do {
		MapTable keyPathToObserverToSelectorToSurrogate = 
			MapTableGet(receiverToKeyPathToObserverToSelectorToSurrogate, receiver);
		if (!keyPathToObserverToSelectorToSurrogate) break;
		
		MapTable observerToSelectorToSurrogate = 
			MapTableGet(keyPathToObserverToSelectorToSurrogate, keyPath);
		if (!observerToSelectorToSurrogate) break;
		
		MapTable selectorToSurrogate = 
			MapTableGet(observerToSelectorToSurrogate, observer);
		if (!selectorToSurrogate) break;
		
		if (!selector) {
			if (!MapTableGetCount(selectorToSurrogate)) break;
			
			/* Remove every observed selector */
			EnumerateMapTable(selectorToSurrogate);
			SEL aSelector;
			Surrogate *aSurrogate;
			while (NextMapEnumeratorPair(selectorToSurrogate, &aSelector, &aSurrogate)) {
				[receiver removeObserver:aSurrogate forKeyPath:keyPath];
			}
			EndMapTableEnumeration(selectorToSurrogate);
			
			/* Remove all selectors */
			MapTableRemove(observerToSelectorToSurrogate, observer);
		} else {
			Surrogate *aSurrogate = MapTableGet(selectorToSurrogate, selector);
			if (!aSurrogate) break;
			
			/* We were observing this key path, remove the observer */
			[receiver removeObserver:aSurrogate forKeyPath:keyPath];
			MapTableRemove(selectorToSurrogate, selector);
		}
		
		/* Clean up unused state */
		if (!MapTableGetCount(selectorToSurrogate)) {
			MapTableRemove(observerToSelectorToSurrogate, observer);
		}
		
		if (!MapTableGetCount(observerToSelectorToSurrogate)) {
			MapTableRemove(keyPathToObserverToSelectorToSurrogate, keyPath);
		}
		
		if (!MapTableGetCount(keyPathToObserverToSelectorToSurrogate)) {
			MapTableRemove(receiverToKeyPathToObserverToSelectorToSurrogate, receiver);
		}
		
		removed = YES;
	} while (0);
	
	pthread_mutex_unlock(&mutex);
	
	return removed;
}

@implementation NSObject (KVOAdditions)

/* For every implementation of `selector' in the superclass tree starting at `klass', replace
 * its implementation with `replacement'. The method identified by `selector' is 
 * duplicated to `newSelector'. Return YES if the implementations on `klass' are
 * already switched. */
+ (void)_replaceSelector:(SEL)selector 
			  withMethod:(Method)replacement
		   duplicatingTo:(SEL)newSelector
	 forAncestorsOfClass:(Class)klass
		 swizzledClasses:(CFMutableSetRef)swizzledClasses
{
	static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
	
	pthread_mutex_lock(&lock);
	
	if (CFSetContainsValue(swizzledClasses, klass)) return;
		
	Method m = class_getInstanceMethod(klass, selector);
	
	/* If the subclass doesn't implement the method, 
	 * the superclass certainly doesn't */
	if (!m) return;
	
	Method superMethod = NULL;
	if (class_getSuperclass(klass)) {
		superMethod = class_getInstanceMethod(class_getSuperclass(klass), selector);
	}
	
	/* If klass's implementation is different than its superclass's
	 * implementation, we need to swizzle it. */
	if (superMethod && (method_getImplementation(m) != method_getImplementation(superMethod))) {
		if (newSelector) {
			/* Duplicate original method to new selector */
			class_addMethod(klass, newSelector, method_getImplementation(m), method_getTypeEncoding(m));
		}
		
		/* And replace old method implementation */
		method_setImplementation(m, method_getImplementation(replacement));
	}
	
	/* Make sure we don't swizzle for this class again */
	CFSetAddValue(swizzledClasses, klass);
	
	pthread_mutex_unlock(&lock);
}

+ (CFMutableSetRef)__deallocClasses
{
	static CFMutableSetRef deallocClasses = nil;
	if (deallocClasses == NULL) {
		deallocClasses = CFSetCreateMutable(kCFAllocatorDefault, 0, NULL);
	}
	
	return deallocClasses;
}

+ (void)_insertDealloc
{
	CFMutableSetRef deallocClasses = [self __deallocClasses];
	if (!CFSetContainsValue(deallocClasses, self)) {
		Method dealloc = class_getInstanceMethod([NSObject class], @selector(__KVOAdditions__dealloc__));
		[self _replaceSelector:@selector(dealloc)
					 withMethod:dealloc 
				  duplicatingTo:@selector(__KVOAdditions__dealloc__original__)
			forAncestorsOfClass:self
				swizzledClasses:deallocClasses];
	}
}

- (void)addObserver:(NSObject *)observer
		 forKeyPath:(NSString *)keyPath
			options:(NSKeyValueObservingOptions)options
		   selector:(SEL)selector
{
	Surrogate *sur = nil;
	
	@try {	
		/* Make a new surrogate for this keyPath and receiver. This object will receive
		 * the observation message */
		sur = [[Surrogate alloc] initWithTarget:observer selector:selector options:options];
		AddObserver(self, sur, observer, selector, keyPath, options);
		
		/* Replace the dealloc method so that we can auto-remove 
		 * self observers and notify an object before it will be deallocated.
		 * No need to override -finalize, as zeroing weak references eliminate
		 * the need to remove observers! */
		[object_getClass(observer) _insertDealloc];
	} @finally {
		[sur release];
	}
}

/* This empty implemention is required because we remain
 * swizzled even after an observer has removed itself
 * from all observed objects. In this case, the 
 * __KVOAdditions__dealloc__original__ method that was added
 * to the KVO swizzled class is no longer present. This method
 * will get called instead in this case. */

- (void)__KVOAdditions__dealloc__original__
{
}

- (void)__KVOAdditions__dealloc__
{
	/* Let the class remove it's observers before it is destroyed */
	if ([[self class] automaticallyRemoveSelfObservations]) {
		RemoveSelfObservations(self);
	}
	
	[self KVODealloc];
	
	/* Call through to KVODeallocate */
	[self __KVOAdditions__dealloc__original__];
}

- (void)KVODealloc
{
}

- (void)removeObserver:(NSObject *)observer 
			forKeyPath:(NSString *)keyPath 
			  selector:(SEL)selector
{
	RemoveObserver(self, keyPath, observer, selector);
}

+ (BOOL)automaticallyRemoveSelfObservations
{
	return YES;
}

@end

@implementation NSArray (KVOAdditions)

- (void)addObserver:(NSObject *)observer
 toObjectsAtIndexes:(NSIndexSet *)indexes
		 forKeyPath:(NSString *)keyPath
			options:(NSKeyValueObservingOptions)options
		   selector:(SEL)selector
{
	Surrogate *sur = nil;
	
	@try {
		for (NSObject *receiver in [self objectsAtIndexes:indexes]) {
			/* Make a new surrogate for this keyPath and receiver. This object
			 * will receive the observation message */
			sur = [[Surrogate alloc] initWithTarget:observer 
										   selector:selector 
											options:options];
			AddObserver(receiver, sur, observer, selector, keyPath, options);
			[sur release];
			sur = nil;
		}
		
		/* Replace the dealloc method so that we can auto-remove 
		 * self observers and notify an object before it will be deallocated.
		 * No need to override -finalize, as zeroing weak references eliminate
		 * the need to remove observers! */
		[object_getClass(observer) _insertDealloc];
	} @finally {
		[sur release];
	}
}

- (void)removeObserver:(NSObject *)observer
  fromObjectsAtIndexes:(NSIndexSet *)indexes
			forKeyPath:(NSString *)keyPath 
			  selector:(SEL)selector
{
	for (NSObject *receiver in [self objectsAtIndexes:indexes]) {
		RemoveObserver(receiver, keyPath, observer, selector);
	}
}

@end
