//
//  NFCMirrorEvidenceSource.m
//  ControlPlane
//
//  Created by Eric Betts on 11/21/14.
//
//

#import "NFCMirrorEvidenceSource.h"

@implementation NFCMirrorEvidenceSource

- (id)init {
  if (!(self = [super init]))
    return nil;

  lock = [[NSLock alloc] init];
  tags = [[NSMutableArray alloc] init];

  return self;
}

- (void)dealloc {
  [lock release];
  [tags release];

  [super dealloc];
}

#pragma mark C callbacks

void MyInputCallback(void *inContext, IOReturn result, void *sender,
                     IOHIDReportType type, uint32_t reportID, uint8_t *report,
                     CFIndex reportLength) {
  // process device response buffer (report) here
  NFCMirrorEvidenceSource *self = (__bridge NFCMirrorEvidenceSource *)inContext;
  NSString *tagID = @"";
  int interface = report[0];
  int method = report[1];
  // int correlationID = report[2] * 255 + report[3];
  int dataLength = report[4];
  uint8_t *data = report + 5;
  if (reportLength == 0 || report[1] == 0) {
    return;
  } else if (reportLength == MIRROR_REPORT_LENGTH) {
    if (interface == TAG_EVENT) {
      tagID = [self bytesToString:data andLength:dataLength];
      [self handleTag:tagID forState:method];
    }
  }
}

static void Handle_DeviceMatchingCallback(void *inContext, IOReturn inResult,
                                          void *inSender,
                                          IOHIDDeviceRef inIOHIDDeviceRef) {
  @autoreleasepool {
    NFCMirrorEvidenceSource *self =
        (__bridge NFCMirrorEvidenceSource *)inContext;
    self.mirror = inIOHIDDeviceRef;
    long reportSize = 0;
    uint8_t *report;
    (void)IOHIDDevice_GetLongProperty(
        inIOHIDDeviceRef, CFSTR(kIOHIDMaxInputReportSizeKey), &reportSize);
    if (reportSize) {
      report = calloc(1, reportSize);
      if (report) {
        IOHIDDeviceRegisterInputReportCallback(
            inIOHIDDeviceRef, report, reportSize, MyInputCallback, inContext);
          NSLog(@"%s", __PRETTY_FUNCTION__);
        //Default to choreo off so I can use at work
        //[self setChoreography:NO];
      }
    }
  }
}

static void Handle_DeviceRemovalCallback(void *inContext, IOReturn inResult,
                                         void *inSender,
                                         IOHIDDeviceRef inIOHIDDeviceRef) {
  @autoreleasepool {
    NFCMirrorEvidenceSource *self =
        (__bridge NFCMirrorEvidenceSource *)inContext;
    self.mirror = nil;
      NSLog(@"%s", __PRETTY_FUNCTION__);
  }
}

- (NSString *)description {
  return NSLocalizedString(@"Create rules based on presence of NFC tag.", @"");
}

- (NSString *)name {
  return @"NFCMirror";
}

- (NSString *)getSuggestionLeadText:(NSString *)type {
  return NSLocalizedString(@"The presence of", @"In rule-adding dialog");
}


- (NSArray *)getSuggestions
{
    NSMutableArray *arr = [NSMutableArray array];
    
    [lock lock];
    NSEnumerator *en = [tags objectEnumerator];
    NSString *aTag;
    while ((aTag = [en nextObject])) {
        [arr addObject:@{@"type": @"NFCMirror", @"parameter": aTag, @"description": aTag}];
    }
    [lock unlock];
    
    return arr;
}

- (NSString *)friendlyName {
  return NSLocalizedString(@"NFC Tag", @"");
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
    BOOL match = NO;
    NSString *inputTag = rule[@"parameter"];
    [lock lock];
    match = [tags containsObject:inputTag];
    [lock unlock];
    return match;
}

- (void)start {
  if (running) {
    return;
  }

  const long vendorId = 0x1da8;
  const long productId = 0x1301;
  NSDictionary *dict = @{
      @kIOHIDProductIDKey: @(productId),
      @kIOHIDVendorIDKey: @(vendorId)
    };
  IOHIDManagerRef managerRef =
      IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
  IOHIDManagerScheduleWithRunLoop(managerRef, CFRunLoopGetCurrent(),
                                  kCFRunLoopDefaultMode);
  IOHIDManagerOpen(managerRef, 0L);
  IOHIDManagerSetDeviceMatching(managerRef, (__bridge CFDictionaryRef)dict);
  IOHIDManagerRegisterDeviceMatchingCallback(
      managerRef, Handle_DeviceMatchingCallback, (__bridge void *)(self));
  IOHIDManagerRegisterDeviceRemovalCallback(
      managerRef, Handle_DeviceRemovalCallback, (__bridge void *)(self));

  running = YES;
}

- (void)stop {
  if (!running) {
    return;
  }
    [self setDataCollected:NO];
  // remove callbacks?

  running = NO;
}

- (NSArray *)getTags {
  NSArray *arr;

  [lock lock];
  arr = [NSArray arrayWithArray:tags];
  [lock unlock];

  return arr;
}

- (void)doUpdate
{
#ifdef DEBUG_MODE
	NSLog(@"%@ >> found %ld tags", [self class], (long) [tags count]);
#endif
}

- (void)clearCollectedData
{
	[lock lock];
	[tags removeAllObjects];
	[self setDataCollected:NO];
	[lock unlock];
}

+ (BOOL)isEvidenceSourceApplicableToSystem {
  return YES; //Figure out how to check currently connected USB devices
}

- (void)handleTag:(NSString *)tagID forState:(int)state {
    NSLog(@"\t\t\t\t%s %@ %i", __PRETTY_FUNCTION__, tagID, state);
    [self setDataCollected:YES];
  if (state == TAG_ON) {
    [lock lock];
    [tags addObject:tagID];
    [lock unlock];
  } else if (state == TAG_OFF) {
    [lock lock];
    [tags removeObject:tagID];
    [lock unlock];
  }
}

- (NSString *)bytesToString:(uint8_t *)bytes andLength:(CFIndex)length {
  NSMutableString *result =
      [NSMutableString stringWithCapacity:2 * length + length - 1];
  for (int i = 0; i < length; i++) {
    [result appendFormat:@"%02X", bytes[i]];
  }
  return [result lowercaseString]; // Result is auto-released
}

- (void)setChoreography:(NSNotification *)notification {
  NSDictionary *userInfo = notification.userInfo;
  NSNumber *state = userInfo[@"state"];
  size_t bufferSize = 64;
  long reportSize = 0;
  uint8_t *outputBuffer = malloc(bufferSize);
  memset(outputBuffer, 0, bufferSize);
  // Interface
  outputBuffer[0] = 0x03;
  // CID
  outputBuffer[2] = 0;
  outputBuffer[3] = 0;
  // length
  outputBuffer[4] = 0;

  if ([state boolValue]) {
    NSLog(@"Choreography on");
    // Method
    outputBuffer[1] = 0x03;
  } else {
    NSLog(@"Choreography off");
    // Method
    outputBuffer[1] = 0x01;
  }
  IOHIDDeviceSetReport(self.mirror, kIOHIDReportTypeOutput, reportSize,
                       outputBuffer, bufferSize);
  free(outputBuffer);
}

static Boolean IOHIDDevice_GetLongProperty(IOHIDDeviceRef inDeviceRef,
                                           CFStringRef inKey, long *outValue) {
  Boolean result = FALSE;
  CFTypeRef tCFTypeRef = IOHIDDeviceGetProperty(inDeviceRef, inKey);
  if (tCFTypeRef) {
    // if this is a number
    if (CFNumberGetTypeID() == CFGetTypeID(tCFTypeRef)) {
      // get its value
      result = CFNumberGetValue((CFNumberRef)tCFTypeRef, kCFNumberSInt32Type,
                                outValue);
    }
  }
  return result;
}

@end
