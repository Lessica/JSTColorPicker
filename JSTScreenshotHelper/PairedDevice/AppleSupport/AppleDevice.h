//
//  AppleDevice.h
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import "JSTPairedDevice.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppleDevice : JSTDevice <JSTPairedDevice>
@property (nonatomic, copy) NSString *productType;
@property (nonatomic, copy) NSString *productVersion;
@end

NS_ASSUME_NONNULL_END
