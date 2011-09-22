#import <Foundation/Foundation.h>
#import "KVOAdditions.h"

@interface Person : NSObject {
	NSString *name;
	NSString *phone;
	NSString *address;
	NSString *city;
}

@property(retain) NSString *name;
@property(retain) NSString *phone;
@property(retain) NSString *address;
@property(retain) NSString *city;

@end

@implementation Person
@synthesize name, phone, address, city;
@end

@interface Programmer : Person {
	NSUInteger loc;
}

@property NSUInteger loc;
@end

@implementation Programmer
@synthesize loc;
@end

@interface A : NSObject {
	Person *person;
}

- (id)initWithPerson:(Person *)person;

@property(retain) Person *person;
@end

@implementation A

- (id)initWithPerson:(Person *)aPerson
{
	if ((self = [super init])) {
		self.person = aPerson;
		[self.person addObserver:self forKeyPath:@"name" options:0 selector:@selector(_a_nameChanged)];
		[self.person addObserver:self forKeyPath:@"phone" options:NSKeyValueObservingOptionNew selector:@selector(_a_phoneChanged:)];
		[self.person addObserver:self forKeyPath:@"address" options:NSKeyValueObservingOptionNew selector:@selector(_a_addressChangedWithOld:andNew:)];
		[self.person addObserver:self forKeyPath:@"city" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionPrior selector:@selector(_a_addressChangedWithOld:andNew:prior:)];
		
		[self addObserver:self forKeyPath:@"person" options:0 selector:@selector(_a_personDidChange)];
		[self addObserver:self forKeyPath:@"person2" options:0 selector:@selector(_a_personDidChange2)];
	}
	
	return self;
}

- (void)KVODealloc
{
	[self.person removeObserver:self forKeyPath:@"name" selector:@selector(_a_nameChanged)];
	[self.person removeObserver:self forKeyPath:@"phone" selector:@selector(_a_phoneChanged:)];
	[self.person removeObserver:self forKeyPath:@"address" selector:@selector(_a_addressChangedWithOld:andNew:)];
	[self.person removeObserver:self forKeyPath:@"city" selector:@selector(_a_addressChangedWithOld:andNew:prior:)];
	
	[super KVODealloc];
}

- (void)dealloc
{
	NSLog(@"A dealloc");
	
	
	self.person = nil;
	[super dealloc];
}

- (void)finalize
{
	NSLog(@"A finalize");
	[super finalize];
}

- (void)_a_nameChanged
{
	NSLog(@"%s", _cmd);
}

- (void)_a_phoneChanged:(NSDictionary *)change
{
	NSLog(@"%s %@", _cmd, change);
}

- (void)_a_addressChangedWithOld:(NSString *)old andNew:(NSString *)new
{
	NSLog(@"%s '%@' to '%@'", _cmd, old, new);
}

- (void)_a_addressChangedWithOld:(NSString *)old andNew:(NSString *)new prior:(BOOL)prior
{
	NSLog(@"%s '%@' to '%@' %d", _cmd, old, new, prior);
}

- (void)_a_personDidChange
{
	NSLog(@"%s", _cmd);
	[self removeObserver:self forKeyPath:@"person" selector:_cmd];
}

@synthesize person;
@end

@interface B : A {}
@end

@implementation B

- (id)initWithProgrammer:(Programmer *)programmer
{
	if ((self = [super initWithPerson:programmer])) {
		[self.person addObserver:self forKeyPath:@"name" options:0 selector:@selector(_nameChanged)];
		[self.person addObserver:self forKeyPath:@"loc" options:0 selector:@selector(_locChanged)];
	}
	
	return self;	
}

- (void)_nameChanged
{
	NSLog(@"%s", _cmd);
}

- (void)_locChanged
{
	NSLog(@"%s", _cmd);
}

- (void)arrayChanged:(NSString *)old withNew:(NSString *)new
{
	NSLog(@"%s %@ %@", _cmd, old, new);
}

- (void)KVODealloc
{
	[self.person removeObserver:self forKeyPath:@"name" selector:@selector(_nameChanged)];
	[self.person removeObserver:self forKeyPath:@"loc" selector:@selector(_locChanged)];
	
	[super KVODealloc];
}

- (void)finalize
{
	NSLog(@"b finalize");
	[super finalize];
}

- (void)dealloc
{
	NSLog(@"B dealloc");
	
	[super dealloc];
}

@end



void doStuff() {
	
	
	for (int i = 0; i < 3; i++) {
		NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		
		[[NSGarbageCollector defaultCollector] collectExhaustively];
		
		Programmer *p = [[[Programmer alloc] init] autorelease];
		B *object = [[B alloc] initWithProgrammer:p];
		
		p.name = @"A Cool Dude";
		p.phone = @"555-555-5555";
		p.address = @"5934 NE 23rd St";
		p.city = @"Columbus";
		p.loc = 5000;
		object.person = p;
		
		NSArray *array = [NSArray arrayWithObject:p];
		[array addObserver:object toObjectsAtIndexes:[NSIndexSet indexSetWithIndex:0] forKeyPath:@"name" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld selector:@selector(arrayChanged:withNew:)];
		
		[array setValue:@"a new name!" forKeyPath:@"name"];
		[array removeObserver:object fromObjectsAtIndexes:[NSIndexSet indexSetWithIndex:0] forKeyPath:@"name" selector:@selector(arrayChanged:withNew:)];
		
		[object release];
		[pool drain];
	}
	
	[[NSGarbageCollector defaultCollector] collectExhaustively];
}

int main (int argc, const char * argv[]) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	doStuff();
	
	
	
	[[NSGarbageCollector defaultCollector] collectExhaustively];
	
	[pool drain];
	
	[[NSRunLoop currentRunLoop] run];
	return 0;
}
