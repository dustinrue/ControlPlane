//
//  ConnectBluetoothDeviceAction.m
//  ControlPlane
//
//  Created by Chris Lundie on 1/May/2014.
//

#import "ConnectBluetoothDeviceAction.h"
#import "ToggleBluetoothAction.h"
#import <IOBluetooth/IOBluetooth.h>

@interface ConnectBluetoothDeviceAction ()

@property (copy) NSString *deviceAddressString;

@end

@implementation ConnectBluetoothDeviceAction

- (instancetype)initWithOption:(NSString *)option
{
  self = [super init];
  if (self) {
    self.deviceAddressString = option;
  }
  return self;
}

- (instancetype)init
{
  return [self initWithOption:@""];
}

- (instancetype)initWithDictionary:(NSDictionary *)dict
{
  return [self initWithOption:dict[@"parameter"]];
}

- (void)dealloc
{
  self.deviceAddressString = nil;
  [super dealloc];
}

- (NSMutableDictionary *)dictionary
{
  NSMutableDictionary *dict = [super dictionary];
  dict[@"parameter"] = [[self.deviceAddressString copy] autorelease];
  return dict;
}

- (NSString *)description
{
  NSString *format = NSLocalizedString(
    @"Connecting to Bluetooth device '%@'.", @"");
  return [NSString stringWithFormat:format, self.deviceAddressString];
}

- (BOOL)execute:(NSString **)errorString
{
  ToggleBluetoothAction *toggleAction =
    [[[ToggleBluetoothAction alloc] initWithOption:@YES] autorelease];
  NSString *error = nil;
  BOOL didToggle = [toggleAction execute:&error];
  if (!didToggle) {
    NSLog(@"%s Aborting because Bluetooth could not be turned on",
          __PRETTY_FUNCTION__);
    *errorString = [[error copy] autorelease];
    return NO;
  }
  IOBluetoothDevice *device =
    [IOBluetoothDevice deviceWithAddressString:self.deviceAddressString];
  IOReturn ioReturn = [device openConnection];
  if (!device || (ioReturn != kIOReturnSuccess)) {
    NSLog(@"%1$s Failed to connect to bluetooth device %2$@, return code %3$d",
          __PRETTY_FUNCTION__, self.deviceAddressString, (int)ioReturn);
  }
  return device && (ioReturn == kIOReturnSuccess);
}

+ (NSString *)helpText
{
  return NSLocalizedString(
    @"The parameter for ConnectBluetoothDevice actions is the address of the"
    @" device.",
    @"");
}

+ (NSString *)creationHelpText
{
  return NSLocalizedString(@"Connecting to Bluetooth device", @"");
}

+ (NSArray *)limitedOptions
{
  NSArray *devices = [IOBluetoothDevice pairedDevices];
  NSMutableArray *options = [NSMutableArray array];
  for (IOBluetoothDevice *device in devices) {
    NSString *deviceName = device.nameOrAddress;
    NSString *deviceAddress = device.addressString;
    if (deviceName && deviceAddress) {
      [options addObject:@{
        @"option": [[deviceAddress copy] autorelease],
        @"description": [[deviceName copy] autorelease],
      }];
    }
  }
  return options;
}

+ (NSString *)friendlyName
{
  return NSLocalizedString(@"Connect Bluetooth Device", @"");
}

+ (NSString *)menuCategory
{
  return NSLocalizedString(@"Networking", @"");
}

@end
