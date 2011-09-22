/*
 * KVOAdditions.h
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <devin at shiftedbits dot org> (Devin Lane) wrote this file. 
 * As long as you retain this notice you can do whatever you want with this 
 * stuff. If we meet some day, and you think this stuff is worth it, you can
 * buy me a beer in return.
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

#import <Foundation/Foundation.h>

@interface NSObject (KVOAdditions)

/* Register `observer' for changes of the value at `keyPath` relative to the
 * receiver.  `selector' is invoked on `observer' when the value is modified
 * according to the specified options. A single observer can observe a single
 * keyPath with multiple selectors. This allows a class and a subclass to 
 * observe the same key path on an object. Due to this, it is recommended
 * that externally available classes that use this observation mechanism
 * use _<class>_ as a prefix to their observation selectors to avoid naming 
 * conflicts.
 *
 * `selector' should have one of the following signatures:
 *
 * 1. - (void)valueDidChange;
 *		Receive nothing about the observed change.
 *
 * 2. - (void)valueDidChange:(NSDictionary *)change;
 *		Receive the raw change dictionary.
 *
 * In addition, if NSKeyValueObservingOptionOld or NSKeyValueObservingOptionNew
 * is included in options, the following can be used:
 *
 * 3. - (void)valueDidChange:(id)oldValue newValue:(id)newValue
 *		Receive the old and new values, both of which can be nil.
 *
 * 4. - (void)valueDidChange:(id)oldValue newValue:(id)newValue isPrior:(BOOL)prior
 *		Receive the old and new values, both of which can be nil. `prior' is true 
 *		if this is a prior notification (if NSKeyValueChangeNotificationIsPriorKey is 
 *		included in the change dictionary.)
 */

- (void)addObserver:(NSObject *)observer
		 forKeyPath:(NSString *)keyPath
			options:(NSKeyValueObservingOptions)options
		   selector:(SEL)selector;

/* Deregister `observer' of the value at `keyPath', relative to the receiver,
 * for which notifications are sent to `selector'. Pass NULL for `selector' 
 * to remove notifications for all registered selectors. */

- (void)removeObserver:(NSObject *)observer 
			forKeyPath:(NSString *)keyPath 
			  selector:(SEL)selector;

/* Return YES if observations on the receiver by the receiver
 * should be automatically removed when the receiver is deallocated
 * or finalized. Defaults to YES. */

+ (BOOL)automaticallyRemoveSelfObservations;

/* Sent right before an object will deallocate. When received, the receiver 
 * should deregister itself as an observer for any properties it is observing
 * on itself. This message is not sent under GC. */

- (void)KVODealloc;

@end

@interface NSArray (KVOAdditions)

/* Adds observer `observer' for keyPath `keyPath' with options `options' to 
 * the objects at indices `indexes' in the receiving array. This is the
 * equivalent of adding the observer using the method above for each of the
 * objects in `indexes'. Using this method, unlike 
 * addObserver:toObjectsAtIndexes:forKeyPath:options:context: is not faster 
 * than individually observing the desired objects. */

- (void)addObserver:(NSObject *)observer
 toObjectsAtIndexes:(NSIndexSet *)indexes
		 forKeyPath:(NSString *)keyPath
			options:(NSKeyValueObservingOptions)options
		   selector:(SEL)selector;

/* Deregister `observer' of the value at `keyPath', relative to the objects 
 * in the receiver at `indexes', for which notifications are sent to 
 * `selector'. Pass NULL for `selector' to remove notifications for all
 * registered selectors. */

- (void)removeObserver:(NSObject *)observer
  fromObjectsAtIndexes:(NSIndexSet *)indexes
			forKeyPath:(NSString *)keyPath 
			  selector:(SEL)selector;
@end
