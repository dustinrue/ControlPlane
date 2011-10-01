//
//  TimeOfDayRule.m
//  ControlPlane
//
//  Created by David Jennes on 30/09/11.
//  Copyright 2011. All rights reserved.
//

#import "TimeOfDayRule.h"

@interface TimeOfDayRule (Private)

- (void) checkMatch;
- (BOOL) matchesDay: (NSDate *) date;
- (BOOL) isAfterStart: (NSDate *) date;
- (BOOL) isBeforeEnd: (NSDate *) date;

@end

@implementation TimeOfDayRule

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_timer = nil;
	m_start = nil;
	m_end = nil;
	m_day = kAllDays;
	
	return self;
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Time Of Day", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"System", @"Rule category");
}

- (void) beingEnabled {
	m_timer = [NSTimer scheduledTimerWithTimeInterval: 60.0
											   target: self
											 selector: @selector(checkMatch)
											 userInfo: nil
											  repeats: NO];
}

- (void) beingDisabled {
	[m_timer invalidate];
	m_timer = nil;
}

- (void) loadData {
	m_start = [self.data valueForKeyPath: @"parameter.start"];
	m_end = [self.data valueForKeyPath: @"parameter.end"];
	m_day = [[self.data valueForKeyPath: @"parameter.day"] intValue];
}

- (NSArray *) suggestedValues {
	NSDateFormatter *formatter = [[NSDateFormatter new] autorelease];
	[formatter setDateFormat: @"HH:mm"];
	
	return [NSArray arrayWithObject:
			[NSDictionary dictionaryWithObjectsAndKeys:
			 [NSDictionary dictionaryWithObjectsAndKeys:
			  [formatter dateFromString: @"09:00"], @"start",
			  [formatter dateFromString: @"17:00"], @"end",
			  [NSNumber numberWithInt: kAllDays], @"day",
			  nil], @"parameter",
			 NSLocalizedString(@"Every Day", @"TimeOfDayRule suggestion description"), @"description",
			 nil]];
}

#pragma mark - Rule checking

- (void) checkMatch {
	NSDate *now = NSDate.date;
	
	self.match = ([self matchesDay: now] &&
				  [self isAfterStart: now] &&
				  [self isAfterStart: now]);
}

- (BOOL) matchesDay: (NSDate *) date {
	NSCalendar *calendar = [[[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar] autorelease];
	[calendar setFirstWeekday: 2];	// Monday
	NSInteger weekday = [calendar components: NSWeekdayCalendarUnit fromDate: date].weekday;
	
	// match?
	switch (m_day) {
		case kWeekDay:
			return weekday < 6;
		case kWeekend:
			return weekday > 5;
		case kAllDays:
			return YES;
		default:
			return weekday == m_day;
	}
}

- (BOOL) isAfterStart: (NSDate *) date {
	NSCalendar *calendar = [[[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar] autorelease];
	
	NSDateComponents *compDate = [calendar components: NSHourCalendarUnit | NSMinuteCalendarUnit fromDate: date];
	NSDateComponents *compStart = [calendar components: NSHourCalendarUnit | NSMinuteCalendarUnit fromDate: m_start];
	
	return (compStart.hour < compDate.hour ||
			(compStart.hour == compDate.hour && compStart.minute <= compDate.minute));
}

- (BOOL) isBeforeEnd: (NSDate *) date {
	NSCalendar *calendar = [[[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar] autorelease];
	
	NSDateComponents *compDate = [calendar components: NSHourCalendarUnit | NSMinuteCalendarUnit fromDate: date];
	NSDateComponents *compEnd = [calendar components: NSHourCalendarUnit | NSMinuteCalendarUnit fromDate: m_end];
	
	return (compDate.hour < compEnd.hour ||
			(compDate.hour == compEnd.hour && compDate.minute <= compEnd.minute));
}

@end
