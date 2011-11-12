//
//  ViewsManager.h
//  ControlPlane
//
//  Created by David Jennes on 11/10/11.
//  Copyright 2011. All rights reserved.
//

@class View;

@interface ViewsManager : NSObject {
	NSMutableDictionary *m_viewTypes;
	NSMutableDictionary *m_viewsAssociation;
}

+ (ViewsManager *) sharedViewsManager;
- (void) registerViewType: (Class) type;
- (void) unregisterViewType: (Class) type;
- (View *) viewObject: (id) object;

@end
