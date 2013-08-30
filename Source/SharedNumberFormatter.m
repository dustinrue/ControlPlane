//
//  SharedNumberFormatter.m
//  ControlPlane
//
//  Created by Vladimir Beloborodov (VladimirTechMan) on 03 August 2013.
//

#import "SharedNumberFormatter.h"

@implementation SharedNumberFormatter

+ (NSNumberFormatter *)percentStyleFormatter {
    static NSNumberFormatter *numberFormatter = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        numberFormatter = [[NSNumberFormatter alloc] init];
        [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
        [numberFormatter setNumberStyle:NSNumberFormatterPercentStyle];
    });

    return numberFormatter;
}

@end
