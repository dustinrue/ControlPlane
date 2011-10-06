//
//  FireWireSource.h
//  ControlPlane
//
//  Created by David Jennes on 29/09/11.
//  Copyright 2011. All rights reserved.
//

#import <Plugins/Sources.h>

@interface FireWireSource : CallbackSource<CallbackSourceProtocol> {
	NSDictionary *m_devices;
	
	IONotificationPortRef m_notificationPort;
	CFRunLoopSourceRef m_runLoopSource;
	io_iterator_t m_addedIterator;
	io_iterator_t m_removedIterator;
}

@property (readwrite, copy) NSDictionary *devices;

@end
