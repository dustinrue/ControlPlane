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

- (NSArray *) listOfDays {
	static NSArray *days = nil;
	
	if (!days) {
		NSMutableArray *list = [[NSMutableArray new] autorelease];
		[list addObject: NSLocalizedString(@"Every Day", @"TimeOfDayRule day description")];
		[list addObject: NSLocalizedString(@"Monday", @"TimeOfDayRule day description")];
		[list addObject: NSLocalizedString(@"Tuesday", @"TimeOfDayRule day description")];
		[list addObject: NSLocalizedString(@"Wednesday", @"TimeOfDayRule day description")];
		[list addObject: NSLocalizedString(@"Thursday", @"TimeOfDayRule day description")];
		[list addObject: NSLocalizedString(@"Friday", @"TimeOfDayRule day description")];
		[list addObject: NSLocalizedString(@"Saturday", @"TimeOfDayRule day description")];
		[list addObject: NSLocalizedString(@"Sunday", @"TimeOfDayRule day description")];
		[list addObject: NSLocalizedString(@"Weekdays", @"TimeOfDayRule day description")];
		[list addObject: NSLocalizedString(@"Weekend", @"TimeOfDayRule day description")];
		days = [list copy];
	}
	
	return days;
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

- (void) loadData: (id) data {
	m_start = [data objectForKey: @"start"];
	m_end = [data objectForKey: @"end"];
	m_day = [[data objectForKey: @"day"] unsignedIntValue];
}

- (NSString *) describeValue: (id) value {
	NSDateFormatter *formatter = [[NSDateFormatter new] autorelease];
	formatter.dateFormat = @"HH:mm";
	
	return [NSString stringWithFormat:
			NSLocalizedString(@"Between %@ and %@ (%@)", @"TimeOfDayRule value description"),
			[formatter stringFromDate: [value objectForKey: @"start"]],
			[formatter stringFromDate: [value objectForKey: @"end"]],
			[self.listOfDays objectAtIndex: [[value objectForKey: @"day"] unsignedIntValue]]];
}

- (NSArray *) suggestedValues {
	NSDateFormatter *formatter = [[NSDateFormatter new] autorelease];
	formatter.dateFormat = @"HH:mm";
	
	return [NSArray arrayWithObject:
			[NSDictionary dictionaryWithObjectsAndKeys:
			 [formatter dateFromString: @"09:00"], @"start",
			 [formatter dateFromString: @"17:00"], @"end",
			 [NSNumber numberWithInt: kAllDays], @"day",
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
