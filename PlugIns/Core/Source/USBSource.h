//
//  USBSource.h
//  ControlPlane
//
//  Created by David Jennes on 30/09/11.
//  Copyright 2011. All rights reserved.
//

#import "CallbackSource.h"

@interface USBSource : CallbackSource<CallbackSourceProtocol> {
	NSArray *m_devices;
	
	IONotificationPortRef m_notificationPort;
	CFRunLoopSourceRef m_runLoopSource;
	io_iterator_t m_addedIterator;
	io_iterator_t m_removedIterator;
}

@property (readwrite, copy) NSArray *devices;

@end
