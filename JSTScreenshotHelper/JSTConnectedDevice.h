//
//  JSTConnectedDevice.h
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^JSTScreenshotHandler)(NSData * _Nullable, NSError * _Nullable);
static const NSErrorDomain kJSTScreenshotError = @"com.jst.error.screenshot";

@interface JSTConnectedDevice : NSObject

@property (nonatomic, copy, readonly) NSString *udid;
@property (nonatomic, copy) NSString *name;

- (instancetype)init NS_UNAVAILABLE;
- (nullable JSTConnectedDevice *)initWithUDID:(NSString *)udid;
+ (nullable JSTConnectedDevice *)deviceWithUDID:(NSString *)udid;
- (void)takeScreenshotWithCompletionHandler:(JSTScreenshotHandler)completion;

@end

NS_ASSUME_NONNULL_END
