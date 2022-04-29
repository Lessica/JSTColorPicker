//
//  JSTPairedDevice.h
//  JSTColorPicker
//
//  Created by Darwin on 2021/12/9.
//  Copyright © 2021 JST. All rights reserved.
//

#import "JSTDevice.h"

NS_ASSUME_NONNULL_BEGIN

@protocol JSTPairedDevice

@property (nonatomic, copy, readonly) NSString *udid;

- (nullable JSTDevice <JSTPairedDevice> *)initWithUDID:(NSString *)udid Type:(NSString *)type;

@end

NS_ASSUME_NONNULL_END
