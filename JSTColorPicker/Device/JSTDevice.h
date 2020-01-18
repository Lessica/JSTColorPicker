//
//  JSTDevice.h
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    JSTScreenshotTypeUnknown,
    JSTScreenshotTypePNG,
    JSTScreenshotTypeTIFF,
} JSTScreenshotType;

typedef void (^JSTScreenshotHandler)(JSTScreenshotType imageType, NSData * _Nullable imageData, NSError * _Nullable error);
static const NSErrorDomain kJSTScreenshotError = @"com.jst.error.screenshot";

@interface JSTDevice : NSObject

@property (nonatomic, copy, readonly) NSString *udid;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSString *menuTitle;

- (instancetype)init NS_UNAVAILABLE;
- (nullable JSTDevice *)initWithUDID:(NSString *)udid;
+ (nullable JSTDevice *)deviceWithUDID:(NSString *)udid;
- (void)screenshotWithCompletionHandler:(JSTScreenshotHandler)completion;

@end

NS_ASSUME_NONNULL_END
