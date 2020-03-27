//
//  JSTScreenshotHelperProtocol.h
//  JSTScreenshotHelper
//
//  Created by Darwin on 3/23/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString * const kJSTColorPickerGroupIdentifier = @"GXZ23M5TP2.com.jst.JSTColorPicker";
static NSString * const kJSTColorPickerBundleIdentifier = @"com.jst.JSTColorPicker";
static NSString * const kJSTColorPickerHelperBundleIdentifier = @"GXZ23M5TP2.com.jst.JSTColorPicker.ScreenshotHelper";
static NSString * const kJSTColorPickerBundleName = @"JSTColorPicker.app";
static NSString * const kJSTColorPickerHelperBundleName = @"JSTColorPickerHelper.app";
static NSString * const kJSTScreenshotHelperBundleIdentifier = @"com.jst.JSTScreenshotHelper";

@protocol JSTScreenshotHelperProtocol

- (void)setNetworkDiscoveryEnabled:(BOOL)enabled;
- (void)discoveredDevicesWithReply:(void (^)(NSData * _Nullable, NSError * _Nullable))reply;
- (void)lookupDeviceByUDID:(NSString *)udid withReply:(void (^)(NSData * _Nullable, NSError * _Nullable))reply;
- (void)takeScreenshotByUDID:(NSString *)udid withReply:(void (^)(NSData * _Nullable, NSError * _Nullable))reply;

@end

NS_ASSUME_NONNULL_END
