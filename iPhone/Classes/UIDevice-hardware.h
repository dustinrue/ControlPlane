/*
 Erica Sadun, http://ericasadun.com
 iPhone Developer's Cookbook, 3.0 Edition
 BSD License, Use at your own risk
 */

#import <UIKit/UIKit.h>

#define IFPGA_NAMESTRING				@"iFPGA"

#define IPHONE_1G_NAMESTRING			@"iPhone 1G"
#define IPHONE_3G_NAMESTRING			@"iPhone 3G"
#define IPHONE_3GS_NAMESTRING			@"iPhone 3GS" 
#define IPHONE_4G_NAMESTRING			@"iPhone 4" 
#define IPHONE_FUTURE_NAMESTRING		@"Future iPhone"
#define IPHONE_UNKNOWN_NAMESTRING		@"Unknown iPhone"

#define IPOD_1G_NAMESTRING				@"iPod touch 1G"
#define IPOD_2G_NAMESTRING				@"iPod touch 2G"
#define IPOD_2GPLUS_NAMESTRING			@"iPod touch 2G Plus"
#define IPOD_3G_NAMESTRING				@"iPod touch 3G"
#define IPOD_4G_NAMESTRING				@"iPod touch 4G"
#define IPOD_FUTURE_NAMESTRING          @"Future iPod"
#define IPOD_UNKNOWN_NAMESTRING			@"Unknown iPod"

#define IPAD_1G_NAMESTRING				@"iPad 1G"
#define IPAD3G_1G_NAMESTRING			@"iPad3G 1G"
#define IPAD_FUTURE_NAMESTRING          @"Future iPad"
#define IPAD_UNKNOWN_NAMESTRING			@"Unknown iPad"

#define IPOD_FAMILY_UNKNOWN_DEVICE			@"Unknown device in the iPhone/iPod family"

#define IPHONE_SIMULATOR_NAMESTRING			@"iPhone Simulator"
#define IPHONE_SIMULATOR_IPHONE_NAMESTRING	@"iPhone Simulator"
#define IPHONE_SIMULATOR_IPAD_NAMESTRING	@"iPad Simulator"

typedef enum {
	UIDeviceUnknown,
	UIDeviceiPhoneSimulator,
	UIDeviceiPhoneSimulatoriPhone,
	UIDeviceiPhoneSimulatoriPad,
	UIDevice1GiPhone,
	UIDevice3GiPhone,
	UIDevice3GSiPhone,
	UIDevice4GiPhone,
	UIDevice1GiPod,
	UIDevice2GiPod,
	UIDevice2GPlusiPod,
	UIDevice3GiPod,
	UIDevice4GiPod,
	UIDevice1GiPad,
	UIDevice1GiPad3G,
	UIDeviceUnknowniPhone,
	UIDeviceUnknowniPod,
	UIDeviceUnknowniPad,
	UIDeviceIFPGA,
    // These constants are for devices we know to be new and probably supersets of their predecessors...
    UIDeviceFutureiPhone,
    UIDeviceFutureiPod,
    UIDeviceFutureiPad
} UIDevicePlatform;

typedef enum {
	UIDeviceFirmware2,
	UIDeviceFirmware3,
	UIDeviceFirmware4,
} UIDeviceFirmware;

// TODO: need to represent this some other way.  We're capped at 32 bits for C enums on a 32-bit platform.
// See http://stackoverflow.com/questions/366017/what-is-the-size-of-an-enum-in-c
typedef enum {
    UIDeviceUnknownCapabilities = 0ULL,
    
	UIDeviceSupportsTelephony = 1 << 0,
	UIDeviceSupportsSMS = 1 << 1,
	UIDeviceSupportsStillCamera = 1 << 2,
	UIDeviceSupportsAutofocusCamera = 1 << 3,
	UIDeviceSupportsVideoCamera = 1 << 4,
	UIDeviceSupportsWifi = 1 << 5,
	UIDeviceSupportsAccelerometer = 1 << 6,
	UIDeviceSupportsLocationServices = 1 << 7,
	UIDeviceSupportsGPS = 1 << 8,
	UIDeviceSupportsMagnetometer = 1 << 9,
	UIDeviceSupportsBuiltInMicrophone = 1 << 10,
	UIDeviceSupportsExternalMicrophone = 1 << 11,
	UIDeviceSupportsOPENGLES1_1 = 1 << 12,
	UIDeviceSupportsOPENGLES2 = 1 << 13,
	UIDeviceSupportsBuiltInSpeaker = 1 << 14,
	UIDeviceSupportsVibration = 1 << 15,
	UIDeviceSupportsBuiltInProximitySensor = 1 << 16,
	UIDeviceSupportsAccessibility = 1 << 17,
	UIDeviceSupportsVoiceOver = 1 << 18,
	UIDeviceSupportsVoiceControl = 1 << 19,
	UIDeviceSupportsBrightnessSensor = 1 << 20,
	UIDeviceSupportsPeerToPeer = 1 << 21,
	UIDeviceSupportsARMV7 = 1 << 22,
	UIDeviceSupportsEncodeAAC = 1 << 23,
	UIDeviceSupportsBluetooth = 1 << 24,
	UIDeviceSupportsNike = 1 << 25,
	UIDeviceSupportsPiezoClicker = 1 << 26,
	UIDeviceSupportsVolumeButtons = 1 << 27,
	UIDeviceSupportsEnhancedMultitouch = 1 << 28, // http://www.boygeniusreport.com/2010/01/13/apples-tablet-is-an-iphone-on-steroids/
    UIDeviceSupportsCameraFlash = 1 << 29,
    UIDeviceSupportsDisplayPort = 1 << 30,
    UIDeviceSupportsFrontFacingCamera = 1 << 31,
    //    UIDeviceSupportsGyroscope = 1 << 32
} UIDeviceCapabilities;

/*
 NOT Covered:
 launch-applications-while-animating, load-thumbnails-while-scrolling,
 delay-sleep-for-headset-click, Unified iPod, standalone contacts,
 fcc-logos-via-software, gas-gauge-battery & hiccough-interval
 */

@interface UIDevice (Hardware)
- (NSString *) platform;
- (NSUInteger) platformType;
+ (UIDeviceCapabilities) platformCapabilities: (UIDevicePlatform) platform;
- (UIDeviceCapabilities) platformCapabilities;
- (NSString *) platformString;
- (NSString *) platformCode;

- (NSArray *) capabilityArray;
- (BOOL) platformHasCapability:(UIDeviceCapabilities)capability;

- (NSUInteger) cpuFrequency;
- (NSUInteger) busFrequency;
- (NSUInteger) totalMemory;
- (NSUInteger) userMemory;

- (NSNumber *) totalDiskSpace;
- (NSNumber *) freeDiskSpace;

- (NSString *) macaddress;
@end