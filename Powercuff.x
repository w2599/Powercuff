#import <UIKit/UIKit.h>
#import <libroot.h>
#import <notify.h>

extern char ***_NSGetArgv(void);

@interface CommonProduct : NSObject
- (void)putDeviceInThermalSimulationMode:(NSString *)simulationMode;
@end

static CommonProduct *currentProduct;
static int token;

#if 0

@implementation NSObject(Powercuff)
+ (id)sharedProduct
{
	return currentProduct;
}

+ (uint64_t)thermalMode
{
	uint64_t thermalMode = 0;
	notify_get_state(token, &thermalMode);
	return thermalMode;
}
@end

#endif

static NSString *stringForThermalMode(uint64_t thermalMode) {
	switch (thermalMode) {
		case 1:
			return @"nominal";
		case 2:
			return @"light";
		case 3:
			return @"moderate";
		case 4:
			return @"heavy";
		default:
			return @"off";
	}
}

static void ApplyThermals(void)
{
	uint64_t thermalMode = 0;
	notify_get_state(token, &thermalMode);
	[currentProduct putDeviceInThermalSimulationMode:stringForThermalMode(thermalMode)];
}

%group thermalmonitord

%hook CommonProduct
- (id)initProduct:(id)data
{
	if ((self = %orig())) {
		if ([self respondsToSelector:@selector(putDeviceInThermalSimulationMode:)]) {
			currentProduct = self;
			ApplyThermals();
		}
	}
	return self;
}

- (void)dealloc
{
	if (currentProduct == self) {
		currentProduct = nil;
	}
	%orig();
}
%end

%end

@interface _CDBatterySaver : NSObject
+ (_CDBatterySaver *)batterySaver;
- (NSInteger)getPowerMode;
@end

static void LoadSettings(void)
{
	CFPropertyListRef powerMode = CFPreferencesCopyValue(CFSTR("PowerMode"), CFSTR("com.rpetrich.powercuff"), kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
	uint64_t thermalMode = 0;
	if (powerMode) {
		if ([(__bridge id)powerMode isKindOfClass:[NSNumber class]]) {
			thermalMode = (uint64_t)[(__bridge NSNumber *)powerMode unsignedLongLongValue];
		}
		CFRelease(powerMode);
	}
	CFPropertyListRef requireLowPowerMode = CFPreferencesCopyValue(CFSTR("RequireLowPowerMode"), CFSTR("com.rpetrich.powercuff"), kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
	if (requireLowPowerMode && [(__bridge id)requireLowPowerMode isKindOfClass:[NSNumber class]] && [(__bridge id)requireLowPowerMode boolValue]) {
		if ([[%c(_CDBatterySaver) batterySaver] getPowerMode] == 0) {
			thermalMode = 0;
		}
	}
	NSLog(@"[----]thermalMode = %llu",thermalMode);
	notify_set_state(token, thermalMode);
	notify_post("com.rpetrich.powercuff.thermals");
}

void batteryLevelDidChange() {
	LoadSettings();
}

%group SpringBoard

%hook SpringBoard
- (void)_batterySaverModeChanged:(NSInteger)arg1
{
	%orig();
	LoadSettings();
}
%end

%end

%ctor
{
	notify_register_check("com.rpetrich.powercuff.thermals", &token);
	char *argv0 = **_NSGetArgv();
    char *path = strrchr(argv0, '/');
    path = path == NULL ? argv0 : path + 1;
    if (strcmp(path, "thermalmonitord") == 0) {
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (void *)ApplyThermals, CFSTR("com.rpetrich.powercuff.thermals"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		[[NSNotificationCenter defaultCenter]
			addObserverForName:UIDeviceBatteryLevelDidChangeNotification
			object:nil
			queue:[NSOperationQueue mainQueue]
			usingBlock:^(NSNotification * _Nonnull note) {
				batteryLevelDidChange();
			}
		];
		%init(thermalmonitord);
    } else {
	    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
		CFNotificationCenterAddObserver(center, NULL, (void *)LoadSettings, CFSTR("com.rpetrich.powercuff.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		LoadSettings();
		%init(SpringBoard);
    }
}