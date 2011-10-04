//
//  TimeOfDayRule.h
//  ControlPlane
//
//  Created by David Jennes on 30/09/11.
//  Copyright 2011. All rights reserved.
//

#import "Rule.h"

typedef enum {
	kAllDays = 0,
	kMonday = 1,
	kTuesday = 2,
	kWednesday = 3,
	kThursday = 4,
	kFriday = 5,
	kSaturday = 6,
	kSunday = 7,
	kWeekDay = 8,
	kWeekend = 9
} eDayOfWeek;

@interface TimeOfDayRule : Rule<RuleProtocol> {
	NSDate *m_start;
	NSDate *m_end;
	eDayOfWeek m_day;
	
	NSTimer *m_timer;
}

@end
