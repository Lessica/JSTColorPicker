//
//  JSTXPCDevice.h
//  JSTScreenshotHelper
//
//  Created by Darwin on 3/23/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JSTXPCDevice : NSObject <NSSecureCoding>

@property (nonatomic, copy, readonly) NSString *udid;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSString *menuTitle;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithUDID:(NSString *)udid andName:(NSString *)name NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
