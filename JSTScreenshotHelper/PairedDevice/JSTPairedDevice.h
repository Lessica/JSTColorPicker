//
//  JSTPairedDevice.h
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import "JSTDevice.h"

NS_ASSUME_NONNULL_BEGIN

@interface JSTPairedDevice : JSTDevice

@property (nonatomic, copy, readonly) NSString *udid;

- (nullable JSTPairedDevice *)initWithUDID:(NSString *)udid type:(NSString *)type;
+ (nullable JSTPairedDevice *)deviceWithUDID:(NSString *)udid type:(NSString *)type;

@end

NS_ASSUME_NONNULL_END
