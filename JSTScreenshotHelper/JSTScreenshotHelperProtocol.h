//
//  JSTScreenshotHelperProtocol.h
//  JSTScreenshotHelper
//
//  Created by Darwin on 3/23/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <unistd.h>
#import <sys/types.h>
#import <pwd.h>
#import <assert.h>

NS_ASSUME_NONNULL_BEGIN

static NSString * const kJSTColorPickerGroupIdentifier = @"GXZ23M5TP2.com.jst.JSTColorPicker";
static NSString * const kJSTColorPickerBundleIdentifier = @"com.jst.JSTColorPicker";
static NSString * const kJSTColorPickerHelperBundleIdentifier = @"GXZ23M5TP2.com.jst.JSTColorPicker.ScreenshotHelper";
static NSString * const kJSTColorPickerBundleName = @"JSTColorPicker.app";
static NSString * const kJSTColorPickerHelperBundleName = @"JSTColorPickerHelper.app";
static NSString * const kJSTColorPickerHelperErrorDomain = @"com.jst.JSTScreenshotHelper.error";

typedef NSString * JSTDeviceType;
static JSTDeviceType const JSTDeviceTypeUSB = @"usb";
static JSTDeviceType const JSTDeviceTypeNetwork = @"network";
static JSTDeviceType const JSTDeviceTypeBonjour = @"bonjour";

typedef void (^JSTScreenshotHandler)(NSData * _Nullable, NSError * _Nullable);
static const NSErrorDomain kJSTScreenshotError = @"com.jst.error.screenshot";

NS_INLINE NSString *RealHomeDirectory() {
    struct passwd *pw = getpwuid(getuid());
    if (!pw) { return nil; }
    return [NSString stringWithUTF8String:pw->pw_dir];
}
NS_INLINE NSString *GetJSTColorPickerHelperLaunchAgentPath() {
    NSString *homePath = RealHomeDirectory();
    if (homePath != nil) {
        return [homePath stringByAppendingPathComponent:@"Library/LaunchAgents/com.jst.JSTColorPicker.ScreenshotHelper.plist"];
    }
    return [@"~/Library/LaunchAgents/com.jst.JSTColorPicker.ScreenshotHelper.plist" stringByExpandingTildeInPath];
}
NS_INLINE NSString *GetJSTColorPickerHelperApplicationPath() {
    NSString *homePath = RealHomeDirectory();
    if (homePath != nil) {
        return [homePath stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/Application Support/JSTColorPicker/%@", kJSTColorPickerHelperBundleName]];
    }
    return [[NSString stringWithFormat:@"~/Library/Application Support/JSTColorPicker/%@", kJSTColorPickerHelperBundleName] stringByExpandingTildeInPath];
}
NS_INLINE NSString *GetJSTColorPickerDeviceSupportPath() {
    NSString *homePath = RealHomeDirectory();
    if (homePath != nil) {
        return [homePath stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/Application Support/%@/DeviceSupport", kJSTColorPickerBundleIdentifier]];
    }
    return [[NSString stringWithFormat:@"~/Library/Application Support/%@/DeviceSupport", kJSTColorPickerBundleIdentifier] stringByExpandingTildeInPath];
}

static NSString * const kJSTScreenshotHelperBundleIdentifier = @"com.jst.JSTScreenshotHelper";

@protocol JSTScreenshotHelperProtocol

- (void)getHelperInfoDictionary:(void (^)(NSData * _Nullable, NSError * _Nullable))reply;
- (void)setNetworkDiscoveryEnabled:(BOOL)enabled;
- (void)discoverDevices;
- (void)discoveredDevicesWithReply:(void (^)(NSData * _Nullable, NSError * _Nullable))reply;
- (void)lookupDeviceByUDID:(NSString *)udid withReply:(void (^)(NSData * _Nullable, NSError * _Nullable))reply;
- (void)takeScreenshotByUDID:(NSString *)udid withReply:(void (^)(NSData * _Nullable, NSError * _Nullable))reply;
- (void)tellConsoleToStartStreamingWithReply:(void (^)(NSData * _Nullable, NSError * _Nullable))reply;

@end

NS_ASSUME_NONNULL_END
