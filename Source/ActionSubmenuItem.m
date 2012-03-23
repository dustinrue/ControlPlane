//
//  ActionSubmenuItem.m
//  ControlPlane
//
//  Created by Dustin Rue on 3/22/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "ActionSubmenuItem.h"
#import "Action.h"

@implementation ActionSubmenuItem

@synthesize items;
@synthesize target;

- (id) init {
    self = [super init];
    
    if (self) {
        items = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void) dealloc {
    [items release];
    
    [super dealloc];
}
- (void) addObject:(id) object {
    [items addObject:object];
}
- (BOOL) menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel {

    SEL addAction = NSSelectorFromString(@"addAction:");
    
    [item setTitle:[[[items objectAtIndex:index] objectForKey:@"class"] friendlyName]];
    [item setTarget:target];
    [item setRepresentedObject:[[items objectAtIndex:index] objectForKey:@"representedObject"]];
    [item setAction:addAction];
    
    return YES;
}

- (NSInteger) numberOfItemsInMenu:(NSMenu *)menu {
    return [items count];
}
    

@end
