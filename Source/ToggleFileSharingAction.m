//
//  ToggleFileSharingAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 3/17/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "ToggleFileSharingAction.h"
#import "Action+HelperTool.h"
#import "DSLogger.h"

@implementation ToggleFileSharingAction

- (NSString *) description {
	if (([turnOn intValue] == kCPAFPEnable) || ([turnOn intValue] == kCPAFPAndSMBEnable) || ([turnOn intValue] == kCPSMBEnable) || ([turnOn intValue] == kCPAFPAndSMBEnable))
		return NSLocalizedString(@"Enabling File Sharing.", @"Act of turning on or enabling File Sharing is being performed");
	else
		return NSLocalizedString(@"Disabling File Sharing.", @"Act of turning off or disabling File Sharing is being performed");
}

- (BOOL) execute: (NSString **) errorString {
    
    BOOL afpStatusFailed = NO;
    BOOL smbdStatusFailed = NO;
    BOOL enabling = NO;
        
    if (([turnOn intValue] == kCPAFPEnable) || ([turnOn intValue] == kCPAFPAndSMBEnable)) {
        enabling = YES;
        if (![self helperToolPerformAction:@kCPHelperToolEnableAFPFileSharingCommand withParameter:@kCPHelperToolAFPServiceName]) 
            afpStatusFailed = YES;
    }
    else if (([turnOn intValue] == kCPAFPDisable) || ([turnOn intValue] == kCPAFPAndSMBDisable)) {
        if (![self helperToolPerformAction:@kCPHelperToolDisableAFPFileSharingCommand withParameter:@kCPHelperToolAFPServiceName]) 
            afpStatusFailed = YES;
    }
    
    
    if (([turnOn intValue] == kCPSMBEnable) || ([turnOn intValue] == kCPAFPAndSMBEnable)) {
        enabling = YES;
        if (![self helperToolPerformAction:@kCPHelperToolEnableSMBFileSharingCommand withParameter:@kCPHelperToolSMBDServiceName]) {
            smbdStatusFailed = YES;
        }
    }
    else if (([turnOn intValue] == kCPSMBDisable) || ([turnOn intValue] == kCPAFPAndSMBDisable)) {
        if (![self helperToolPerformAction:@kCPHelperToolDisableSMBFileSharingCommand withParameter:@kCPHelperToolSMBDServiceName])
            smbdStatusFailed = YES;
            
    }
    
    
	if (afpStatusFailed || smbdStatusFailed) {
		if (enabling)
			*errorString = NSLocalizedString(@"Failed enabling File Sharing.", @"Act of turning off or disabling File Sharing failed");
		else
			*errorString = NSLocalizedString(@"Failed disabling File Sharing.", @"Act of turning off or disabling File Sharing failed");
	}

    
	return (!afpStatusFailed && !smbdStatusFailed);
}

+ (NSArray *)limitedOptions
{
	return [NSArray arrayWithObjects:
            [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCPAFPEnable], @"option",
             NSLocalizedString(@"AFP Sharing ON", @"Used in toggling actions"), @"description", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCPSMBEnable], @"option",
             NSLocalizedString(@"SMB Sharing ON", @"Used in toggling actions"), @"description", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCPAFPAndSMBEnable], @"option",
             NSLocalizedString(@"AFP & SMB Sharing ON", @"Used in toggling actions"), @"description", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCPAFPDisable], @"option",
             NSLocalizedString(@"AFP Sharing OFF", @"Used in toggling actions"), @"description", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCPSMBDisable], @"option",
             NSLocalizedString(@"SMB Sharing OFF", @"Used in toggling actions"), @"description", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCPAFPAndSMBDisable], @"option",
             NSLocalizedString(@"AFP & SMB Sharing OFF", @"Used in toggling actions"), @"description", nil],
            nil];
}

+ (NSString *) helpText {
	return NSLocalizedString(@"Editing a File Sharing action is not recommended, please delete and add again.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Set File Sharing", @"Will be followed by 'on' or 'off'");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Toggle File Sharing", @"");
}

- (id)initWithOption:(NSObject *)option {
    return [super init];
    
}


- (id)initWithDictionary:(NSDictionary *)dict {

    self = [super initWithDictionary:dict];
    [turnOn autorelease];
    turnOn = [[dict valueForKey:@"parameter"] copy];

    return self;
}
       
+ (NSString *)menuCategory {
    return NSLocalizedString(@"Sharing", @"");
}


@end
