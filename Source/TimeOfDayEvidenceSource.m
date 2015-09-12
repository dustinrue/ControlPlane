//
//  TimeOfDayEvidenceSource.m
//  ControlPlane
//
//  Created by David Symonds on 20/07/07.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import "TimeOfDayEvidenceSource.h"
#import "DSLogger.h"
#import "RuleType.h"

@interface TimeOfDayEvidenceSource ()

// Returns NO on failure
- (BOOL)parseParameter:(NSString *)parameter intoDay:(NSString **)day startTime:(NSDate **)startT endTime:(NSDate **)endT;

@end

#pragma mark -

@implementation TimeOfDayEvidenceSource

- (BOOL)parseParameter:(NSString *)parameter intoDay:(NSString **)day startTime:(NSDate **)startT endTime:(NSDate **)endT
{
	NSArray *arr = [parameter componentsSeparatedByString:@","];
    if ([arr count] != 3) {
        return NO;
    }
    
    *day = arr[0];
    
	*startT = [formatter dateFromString:arr[1]];
    if (startT == nil) {
        DSLog(@"Cannot parse value \"%@\" of parameter \"Start time\" in a \"Time of day\" rule.", arr[1]);
        return NO;
    }
    
	*endT = [formatter dateFromString:arr[2]];
    if (endT == nil) {
        DSLog(@"Cannot parse value \"%@\" of parameter \"End time\" in a \"Time of day\" rule.", arr[2]);
        return NO;
    }
    
	return YES;
}

- (id)init
{
    self = [super initWithNibNamed:@"TimeOfDayRule"];
    if (self == nil) {
        return nil;
    }

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


- (NSString *) description {
    return NSLocalizedString(@"Create rules based on the time of day and day of week.", @"");
}

- (IBAction)closeSheetWithOK:(id)sender
{
    if ([self validatePanelParams]) {
        [super closeSheetWithOK:sender];
    }
}

- (BOOL)validatePanelParams
{
    NSString *startT = [formatter stringFromDate:startTime];
    if (startT == nil) {
        [RuleType alertOnInvalidParamValueWith:NSLocalizedString(@"Start time format is not correct", @"")];
        return NO;
    }
    
    NSString *endT = [formatter stringFromDate:endTime];
    if (endT == nil) {
        [RuleType alertOnInvalidParamValueWith:NSLocalizedString(@"End time format is not correct", @"")];
        return NO;
    }
    
    return YES;
}

- (NSMutableDictionary *)readFromPanel
{
	NSMutableDictionary *dict = [super readFromPanel];
    NSString *param = [NSString stringWithFormat:@"%@,%@,%@", selectedDay,
                       [formatter stringFromDate:startTime], [formatter stringFromDate:endTime]];
    
	// Make formatter for description of times
	NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
	[fmt setFormatterBehavior:NSDateFormatterBehavior10_4];
	[fmt setDateStyle:NSDateFormatterNoStyle];
	[fmt setTimeStyle:NSDateFormatterShortStyle];

	// TODO: improve description?
	NSString *desc = [NSString stringWithFormat:@"%@ %@-%@", selectedDay,
		[fmt stringFromDate:startTime], [fmt stringFromDate:endTime]];

    [fmt release];
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
	NSString *day = nil;
	NSDate *startT = nil, *endT = nil;

    if (![self parseParameter:rule[@"parameter"] intoDay:&day startTime:&startT endTime:&endT]) {
        return NO;
    }

    if (startT == (id)[NSNull null] || endT == (id)[NSNull null]) {
#if DEBUG_MODE
        DSLog(@"Cannot cope with a null startT or endT, returning false");
#endif
        return NO;
    }

    NSCalendarDate *now = [NSCalendarDate calendarDate];
    
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
	NSDateComponents *startC = [cal components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:startT];
	NSDateComponents *endC = [cal components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:endT];
    
    const NSInteger hourNow = [now hourOfDay], minuteNow = [now minuteOfHour];
    BOOL hasStarted = (hourNow > [startC hour]) || ( (hourNow == [startC hour]) && (minuteNow >= [startC minute]) );
    BOOL hasEnded   = (hourNow > [endC hour])   || ( (hourNow == [endC hour])   && (minuteNow >= [endC minute]) );
    
    if ([startT earlierDate:endT] == endT) {  //cross-midnight rule
        return (hasStarted || !hasEnded);
    }
    
	return (hasStarted && !hasEnded);
}

- (NSString *)friendlyName {
    return NSLocalizedString(@"Time Of Day", @"");
}

@end
