//
//  ActionSubmenuItem.h
//  ControlPlane
//
//  Created by Dustin Rue on 3/22/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ActionSubmenuItem : NSObject <NSMenuDelegate> {
    NSMutableArray *items;
    id target;
    id representedObject;
}

@property (readwrite, retain) NSMutableArray *items;
@property (readwrite, assign) id target;
@property (readwrite, assign) id representedObject;

- (void) addObject:(id) object;

@end
