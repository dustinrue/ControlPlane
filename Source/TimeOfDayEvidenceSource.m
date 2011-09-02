//
//  TimeOfDayEvidenceSource.m
//  ControlPlane
//
//  Created by David Symonds on 20/07/07.
//

#import "TimeOfDayEvidenceSource.h"


@interface TimeOfDayEvidenceSource (Private)

// Returns NO on failure
- (BOOL)parseParameter:(NSString *)parameter intoDay:(NSString **)day startTime:(NSDate **)startT endTime:(NSDate **)endT;

@end

#pragma mark -

@implementation TimeOfDayEvidenceSource

- (BOOL)parseParameter:(NSString *)parameter intoDay:(NSString **)day startTime:(NSDate **)startT endTime:(NSDate **)endT
{
	NSArray *arr = [parameter componentsSeparatedByString:@","];
	if ([arr count] != 3)
		return NO;

	*day = [arr objectAtIndex:0];
	// TODO: check day is an element in our list?

	*startT = [formatter dateFromString:[arr objectAtIndex:1]];
	*endT = [formatter dateFromString:[arr objectAtIndex:2]];
	// TODO: check parsing? (maybe by re-encoding string, and comparing)

	return YES;
}

- (id)init
{
	if (!(self = [super initWithNibNamed:@"TimeOfDayRule"]))
		return nil;

	// Create formatter for reading/writing times ("HH:MM" only)
	formatter = [[NSDateFormatter alloc] init];
	[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	[formatter setDateFormat:@"HH:mm"];

	// Fill in day list
	[dayController addObjects:[NSArray arrayWithObjects:
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Any day", @"option", NSLocalizedString(@"Any day", "In TimeOfDay rules"), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Weekday", @"option", NSLocalizedString(@"Weekday", "In TimeOfDay rules"), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Weekend", @"option", NSLocalizedString(@"Weekend", "In TimeOfDay rules"), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Monday", @"option", NSLocalizedString(@"Monday", "In TimeOfDay rules"), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Tuesday", @"option", NSLocalizedString(@"Tuesday", "In TimeOfDay rules"), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Wednesday", @"option", NSLocalizedString(@"Wednesday", "In TimeOfDay rules"), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Thursday", @"option", NSLocalizedString(@"Thursday", "In TimeOfDay rules"), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Friday", @"option", NSLocalizedString(@"Friday", "In TimeOfDay rules"), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Saturday", @"option", NSLocalizedString(@"Saturday", "In TimeOfDay rules"), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Sunday", @"option", NSLocalizedString(@"Sunday", "In TimeOfDay rules"), @"description", nil],
		nil]];

	return self;
}

- (void)dealloc
{
	[formatter release];

	[super dealloc];
}

- (NSMutableDictionary *)readFromPanel
{
	NSMutableDictionary *dict = [super readFromPanel];

	// Make formatter for description of times
	NSDateFormatter *fmt = [[[NSDateFormatter alloc] init] autorelease];
	[fmt setFormatterBehavior:NSDateFormatterBehavior10_4];
	[fmt setDateStyle:NSDateFormatterNoStyle];
	[fmt setTimeStyle:NSDateFormatterShortStyle];

	NSString *param = [NSString stringWithFormat:@"%@,%@,%@", selectedDay,
		[formatter stringFromDate:startTime], [formatter stringFromDate:endTime]];
	// TODO: improve description?
	NSString *desc = [NSString stringWithFormat:@"%@ %@-%@", selectedDay,
		[fmt stringFromDate:startTime], [fmt stringFromDate:endTime]];

	[dict setValue:param forKey:@"parameter"];
	if (![dict objectForKey:@"description"])
		[dict setValue:desc forKey:@"description"];

	return dict;
}

- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type
{
	[super writeToPanel:dict usingType:type];

	NSString *day;
	NSDate *startT, *endT;
	if ([dict objectForKey:@"parameter"] &&
	    [self parseParameter:[dict valueForKey:@"parameter"] intoDay:&day startTime:&startT endTime:&endT]) {
		[self setValue:day forKey:@"selectedDay"];
		[self setValue:startT forKey:@"startTime"];
		[self setValue:endT forKey:@"endTime"];
	} else {
		// Defaults
		[self setValue:@"Any day" forKey:@"selectedDay"];
		[self setValue:[formatter dateFromString:@"09:00"] forKey:@"startTime"];
		[self setValue:[formatter dateFromString:@"17:00"] forKey:@"endTime"];
	}
}

- (void)start
{
	running = YES;
	[self setDataCollected:YES];
}

- (void)stop
{
	running = NO;
	[self setDataCollected:NO];
}

- (NSString *)name
{
	return @"TimeOfDay";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	NSString *day;
	NSDate *startT, *endT;
	NSCalendarDate *now = [NSCalendarDate calendarDate];

	if (![self parseParameter:[rule valueForKey:@"parameter"] intoDay:&day startTime:&startT endTime:&endT])
		return NO;

	// Check day first
	NSInteger dow = [now dayOfWeek];	// 0=Sunday, 1=Monday, etc.
	if ([day isEqualToString:@"Any day"]) {
		// Okay
	} else if ([day isEqualToString:@"Weekday"]) {
		if ((dow < 1) || (dow > 5))
			return NO;
	} else if ([day isEqualToString:@"Weekend"]) {
		if ((dow != 0) && (dow != 6))
			return NO;
	} else {
		static NSString *day_name[7] = { @"Sunday", @"Monday", @"Tuesday", @"Wednesday",
						@"Thursday", @"Friday", @"Saturday" };
		if (![day isEqualToString:day_name[dow]])
			return NO;
	}

	NSCalendar *cal = [NSCalendar currentCalendar];
	NSDateComponents *startC = [cal components:(NSHourCalendarUnit | NSMinuteCalendarUnit) fromDate:startT];
	NSDateComponents *endC = [cal components:(NSHourCalendarUnit | NSMinuteCalendarUnit) fromDate:endT];

	// Test with startT
	if (([now hourOfDay] < [startC hour]) ||
	    (([now hourOfDay] == [startC hour]) && ([now minuteOfHour] < [startC minute])))
		return NO;
	// Test with endT
	if (([now hourOfDay] > [endC hour]) ||
	    (([now hourOfDay] == [endC hour]) && ([now minuteOfHour] > [endC minute])))
		return NO;

	return YES;
}

@end
