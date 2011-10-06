//
//  LocationSource.h
//  ControlPlane
//
//  Created by David Jennes on 25/09/11.
//  Copyright 2011. All rights reserved.
//

#import <Plugins/Sources.h>
#import <CoreLocation/CoreLocation.h>

@interface LocationSource : CallbackSource<CallbackSourceProtocol, CLLocationManagerDelegate> {
	CLLocation *m_location;
	CLLocationManager *m_manager;
}

@property (readwrite, copy) CLLocation *location;

@end
